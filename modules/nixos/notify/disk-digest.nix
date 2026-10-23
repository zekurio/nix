{
  flake.modules.nixos.base = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.modules.notify;

    # Reduces each drive's `smartctl -j -x` output to what the report shows
    # and the counters it compares with the previous report.
    normalize = pkgs.writeText "disk-digest-normalize.jq" ''
      map(
        ((.ata_smart_attributes.table // []) | map({key: (.id | tostring), value: .}) | from_entries) as $attr
        | ([.ata_device_statistics.pages[]?.table[]? | {key: .name, value: .value}] | from_entries) as $stat
        | (.nvme_smart_health_information_log // {}) as $nvme
        | (.logical_block_size // 512) as $block
        | (.device.type == "nvme" or .rotation_rate == 0) as $ssd
        | {
            # smartctl leaves out the device when it cannot open it.
            dev: (.device.name // .smartctl.argv[-1] | ltrimstr("/dev/")),
            model: .model_name,
            serial: .serial_number,
            passed: .smart_status.passed,
            temp: .temperature.current,
            hours: .power_on_time.hours,
            # ATA SSDs without the device statistic report life left as the
            # normalized value of 177 (Samsung), 231 or 233 (Intel).
            wear: (
              if $ssd then
                $nvme.percentage_used
                // $stat["Percentage Used Endurance Indicator"]
                // (($attr["177"] // $attr["231"] // $attr["233"]).value | values | 100 - .)
              else null end
            ),
            # NVMe counts data units of 1000 512-byte sectors.
            written: (
              if $ssd then
                ($nvme.data_units_written | values | . * 512000)
                // (($stat["Logical Sectors Written"] // $attr["241"].raw.value) | values | . * $block)
              else null end
            ),
            test: (
              ((.ata_smart_self_test_log.extended // .ata_smart_self_test_log.standard).table[0]?
                | values
                | {type: .type.string, passed: .status.passed, hours: .lifetime_hours})
              // (.nvme_self_test_log.table[0]?
                | values
                | {type: .self_test_code.string, passed: (.self_test_result.value == 0), hours: .power_on_hours})
              // null
            ),
            counters: {
              reallocated: $attr["5"].raw.value,
              pending: $attr["197"].raw.value,
              uncorrectable: $attr["198"].raw.value,
              "reported uncorrectable": $attr["187"].raw.value,
              "CRC errors": $attr["199"].raw.value,
              "logged errors": (.ata_smart_error_log.extended // .ata_smart_error_log.summary).count,
              "media errors": $nvme.media_errors
            } | with_entries(select(.value != null))
          }
      )
    '';

    # Error counters list whenever they are nonzero but only raise the
    # priority when they grew since the last report, so errors a drive logged
    # long ago don't make every report urgent.
    report = pkgs.writeText "disk-digest-report.jq" ''
      def size: if . >= 1e12 then "\(. / 1e11 | round / 10) TB" else "\(. / 1e9 | round) GB" end;
      def ago: if . >= 48 then "\(. / 24 | floor)d ago" else "\(.)h ago" end;

      ($prev | map({key: .serial, value: .}) | from_entries) as $last
      | [
          $status.pools | to_entries[] | .value as $pool
          | $list.pools[.key].properties as $usage
          | ($pool.scan_stats // {}) as $scan
          | {
              high: ($pool.state != "ONLINE" or $pool.error_count > 0 or $scan.errors > 0),
              lines: [
                "\(.key) \($pool.state) · \($usage.capacity.value)% of \($usage.size.value | size) used",
                "  " + (
                  if $scan.state == "FINISHED" then
                    "\($scan.function | ascii_downcase) \((now - $scan.end_time) / 3600 | floor | ago), \($scan.errors) errors"
                    + (if $scan.processed > 0 then ", \($scan.processed | size) repaired" else "" end)
                  elif $scan.state == "SCANNING" then "\($scan.function | ascii_downcase) running"
                  elif $scan.state then "\($scan.function | ascii_downcase) \($scan.state | ascii_downcase)"
                  else "never scrubbed" end
                )
              ]
            }
        ] as $pools
      | [
          $drives[] | . as $d | ($last[.serial // ""] // {}) as $p
          | [
              .counters | to_entries[] | select(.value > 0)
              | (.value - ($p.counters[.key] // .value)) as $new
              | {new: ($new > 0), text: "\(.value) \(.key)" + (if $new > 0 then " (+\($new))" else "" end)}
            ] as $problems
          | {
              high: (.passed != true or .test.passed == false or any($problems[]; .new)),
              lines: [
                "\(.dev) \(.model // "?") · "
                  + (if .passed then "ok" elif .passed == false then "FAILING" else "unreadable" end),
                ([
                  (.temp | values | "\(.)°C"),
                  (.hours | values | "\(.) h"),
                  (.wear | values | "\(.)% worn" + (if $p.wear and . > $p.wear then " (+\(. - $p.wear))" else "" end)),
                  (.written | values | "\(size) written" + (if $p.written then " (+\(. - $p.written | size))" else "" end)),
                  (.test | values
                    | "\(.type | split(" ")[0] | ascii_downcase) test "
                      + (if .passed == false then "FAILED" else "ok" end)
                      + (if $d.hours and .hours then " \($d.hours - .hours | ago)" else "" end))
                ] | select(length > 0) | "  " + join(" · ")),
                ($problems | select(length > 0) | "  " + (map(.text) | join(", ")))
              ]
            }
        ] as $disks
      | {
          high: any($pools[], $disks[]; .high),
          text: ([[$pools[].lines[]], [$disks[].lines[]]] | map(select(length > 0) | join("\n")) | join("\n\n"))
        }
    '';

    digest = pkgs.writeShellApplication {
      name = "disk-digest";
      runtimeInputs =
        [pkgs.jq pkgs.smartmontools]
        ++ lib.optional config.boot.zfs.enabled config.boot.zfs.package;
      text = ''
        state="$STATE_DIRECTORY/last.json"

        drives=$(
          smartctl --scan -j | jq -r '.devices[].name' | while read -r dev; do
            # The exit status is a bitmask that stays set for errors a drive
            # logged long ago; the JSON says what is actually wrong.
            smartctl -j -x "$dev" || true
          done | jq -s -f ${normalize}
        )

        status='{"pools": {}}' list='{"pools": {}}'
        if command -v zpool >/dev/null; then
          status=$(zpool status -jp --json-int)
          list=$(zpool list -jp --json-int)
        fi

        prev='[]'
        if [ -f "$state" ]; then
          prev=$(< "$state")
        fi

        result=$(jq -n -f ${report} \
          --argjson drives "$drives" --argjson status "$status" \
          --argjson list "$list" --argjson prev "$prev")
        if [ "$(jq .high <<< "$result")" = true ]; then
          priority=high tags=warning
        else
          priority=low tags=floppy_disk
        fi
        jq -r .text <<< "$result" \
          | ${lib.getExe cfg.package} "${config.networking.hostName}: weekly disk report" "$priority" "$tags"

        # Saved only once the report is out, so a week that failed to send
        # folds into the next report's deltas.
        printf '%s\n' "$drives" > "$state"
      '';
    };
  in {
    options.modules.notify.diskDigest.enable = lib.mkEnableOption "a weekly ntfy report of SMART and pool state";

    config = lib.mkIf (cfg.enable && cfg.diskDigest.enable) {
      systemd.services.disk-digest = {
        description = "Weekly SMART and pool report through ntfy";
        # After both HDDs' weekend short self-tests, which the report lists.
        startAt = "Sun 10:00";
        inherit (cfg) onFailure;
        serviceConfig = {
          Type = "oneshot";
          ExecStart = lib.getExe digest;
          StateDirectory = "disk-digest";
        };
      };

      # Catch up on a report missed while the host was off.
      systemd.timers.disk-digest.timerConfig.Persistent = true;
    };
  };
}

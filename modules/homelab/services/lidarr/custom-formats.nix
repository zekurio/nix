# Custom formats that order Soulseek releases by peer viability.
#
# Results for one album are almost always the same quality, so Lidarr's
# CompareQuality ties and CompareCustomFormatScore becomes the only comparator
# that can pick a winner. The slskd plugin encodes exactly what decides whether
# a grab will succeed in the release title
# (Tubifarry/Core/Model/AlbumData.cs):
#
#   {Artist} - {Album} (Year) [{Codec} {BitDepth}bit] [👤 user ] [{⚡|❌} 12,69MB/s ] [📋 54]? [WEB]
#
# ⚡ is HasFreeUploadSlot and ❌ means the peer has none, so the download would
# queue indefinitely. 📋 N is emitted only when the queue is non-empty. The
# speed is "F2" formatted using the process culture, so the decimal separator
# is a comma here and a dot elsewhere — both are accepted.
#
# Two constraints shape the scale, and both were learned the hard way:
#
#   * Scores must be non-negative. The profile carries minFormatScore = 0 and
#     Lidarr *rejects* a release scoring below it rather than ranking it last,
#     so penalties silently made albums unavailable to automatic search
#     whenever only slow or queued peers were online. Undesirable traits are
#     therefore expressed as absent rewards.
#   * CompareCustomFormatScore runs before CompareProtocol. A Usenet release
#     matches none of the Soulseek formats, so without a baseline it scores 0,
#     loses every equal-quality tie, and the delay profile never gets consulted.
#
# The baseline is therefore derived from the best score a Soulseek release can
# possibly reach, plus a margin, so Usenet wins outright at equal quality rather
# than drawing and depending on CompareProtocol and the delay profile's protocol
# order. Usenet completes whether or not a stranger stays online, so it earns
# that. Soulseek still decides among its own peers, and still wins any quality
# tier Usenet simply does not carry — which, for most of this library, is most
# of them.
#
# Drop the margin to zero to go back to a draw settled by the delay profile, or
# below the Soulseek maximum to let an excellent peer outrank Usenet again.
#
# Regexes are .NET. Emoji are written literally because .NET only understands
# \uHHHH escapes, which cannot express 📋 (U+1F4CB) without a surrogate pair.
{
  flake.modules.nixos.homelab = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.services.homelab.lidarr;

    # Emitted only by the slskd indexer, so its absence identifies every other
    # source.
    soulseekMarker = "MB/s ";

    scores = {
      freeSlot = 50;
      fastPeer = 20;
      mediumPeer = 10;
      noQueue = 20;
      shortQueue = 10;
    };

    # The speed tiers are mutually exclusive by construction, as are the queue
    # tiers, so the best a Soulseek release can do is a free slot plus the
    # better of each pair. Derived rather than written out so that changing any
    # score below keeps the margin intact.
    bestSoulseekScore =
      scores.freeSlot
      + (lib.max scores.fastPeer scores.mediumPeer)
      + (lib.max scores.noQueue scores.shortQueue);

    usenetMargin = 10;

    releaseTitle = regex: {
      name = "release title";
      implementation = "ReleaseTitleSpecification";
      negate = false;
      required = true;
      fields.value = regex;
    };

    notReleaseTitle = regex: (releaseTitle regex) // {negate = true;};
  in {
    options.services.homelab.lidarr.customFormats = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          name = lib.mkOption {
            type = lib.types.str;
            description = ''
              Display name in Lidarr. configarr matches existing formats by
              name, so changing this creates a second format rather than
              renaming the original.
            '';
          };
          score = lib.mkOption {
            type = lib.types.int;
            description = "Score assigned to this format in the quality profile.";
          };
          specifications = lib.mkOption {
            type = lib.types.listOf (lib.types.attrsOf lib.types.anything);
            description = "Lidarr specifications; all of them must match.";
          };
        };
      });
      description = ''
        Custom formats synchronised into Lidarr, keyed by the trash id used to
        reference them. Scores must stay non-negative: the profile's
        minFormatScore rejects anything below it outright.
      '';
      default = {
        "baseline-non-soulseek" = {
          name = "Baseline: Non-Soulseek";
          score = bestSoulseekScore + usenetMargin;
          specifications = [(notReleaseTitle soulseekMarker)];
        };
        "soulseek-free-slot" = {
          name = "Soulseek: Free Slot";
          score = scores.freeSlot;
          specifications = [(releaseTitle "\\[⚡ ")];
        };
        # Anchored right after "[<emoji> " so the speed tiers stay mutually
        # exclusive: "12," cannot match the single-digit tier, because the
        # character following "1" is not a separator.
        "soulseek-fast-peer" = {
          name = "Soulseek: Fast Peer";
          score = scores.fastPeer;
          specifications = [(releaseTitle "\\[[⚡❌] \\d{2,}[.,]")];
        };
        "soulseek-medium-peer" = {
          name = "Soulseek: Medium Peer";
          score = scores.mediumPeer;
          specifications = [(releaseTitle "\\[[⚡❌] [1-9][.,]")];
        };
        # An empty queue can only be matched as an absence, and absence alone
        # would match every Usenet release too, so require the speed token.
        "soulseek-no-queue" = {
          name = "Soulseek: No Queue";
          score = scores.noQueue;
          specifications = [
            (releaseTitle soulseekMarker)
            (notReleaseTitle "\\[📋")
          ];
        };
        "soulseek-short-queue" = {
          name = "Soulseek: Short Queue";
          score = scores.shortQueue;
          specifications = [(releaseTitle "\\[📋 [1-9]\\]")];
        };
      };
    };

    options.services.homelab.lidarr.customFormatsPath = lib.mkOption {
      type = lib.types.package;
      readOnly = true;
      description = "Directory of Trash-format definitions for configarr to load.";
      default = pkgs.linkFarm "lidarr-custom-formats" (
        lib.mapAttrsToList (trashId: format: {
          name = "${trashId}.json";
          path = pkgs.writeText "${trashId}.json" (builtins.toJSON {
            trash_id = trashId;
            includeCustomFormatWhenRenaming = false;
            inherit (format) name specifications;
          });
        })
        cfg.customFormats
      );
    };
  };
}

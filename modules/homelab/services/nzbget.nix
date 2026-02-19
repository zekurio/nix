{
  config,
  lib,
  pkgs,
  ...
}: let
  domain = "nzb.schnitzelflix.xyz";
  port = 6789;
  serviceUser = "nzbget";
  serviceGroup = "nzbget";
  deleteSamplesScript = pkgs.writeTextFile {
    name = "DeleteSamples.py";
    executable = true;
    text = ''
      #!/usr/bin/env python
      import os
      import sys

      NZBGET_POSTPROCESS_SUCCESS = 93
      NZBGET_POSTPROCESS_ERROR = 94
      NZBGET_POSTPROCESS_NONE = 95

      def is_sample(file_path, input_name, max_sample_size, sample_ids):
          size_cutoff = int(max_sample_size) * 1024 * 1024
          if os.path.getsize(file_path) >= size_cutoff:
              return False
          if "SizeOnly" in sample_ids:
              return True
          lower_path = file_path.lower()
          lower_name = input_name.lower()
          return any(ident.lower() in lower_path and ident.lower() not in lower_name for ident in sample_ids)

      if "NZBOP_SCRIPTDIR" not in os.environ:
          print("This script can only be called from NZBGet (11.0 or later).")
          sys.exit(0)

      if os.environ["NZBOP_VERSION"][0:5] < "11.0":
          print("NZBGet Version %s is not supported. Please update NZBGet." % os.environ["NZBOP_VERSION"])
          sys.exit(0)

      print("Script triggered from NZBGet Version %s." % os.environ["NZBOP_VERSION"])
      status = 0

      if "NZBPP_TOTALSTATUS" in os.environ:
          if os.environ["NZBPP_TOTALSTATUS"] != "SUCCESS":
              print("Download failed with status %s." % os.environ.get("NZBPP_STATUS", ""))
              status = 1
      else:
          if os.environ.get("NZBPP_PARSTATUS") in {"1", "4"}:
              print("Par-repair failed, setting status \"failed\".")
              status = 1

          if os.environ.get("NZBPP_UNPACKSTATUS") == "1":
              print("Unpack failed, setting status \"failed\".")
              status = 1

          if os.environ.get("NZBPP_UNPACKSTATUS") == "0" and os.environ.get("NZBPP_PARSTATUS") == "0":
              if os.environ.get("NZBPP_HEALTH", "0") < "1000":
                  print("Download health is compromised and Par-check/repair disabled or no .par2 files found. Setting status \"failed\".")
                  print("Please check your Par-check/repair settings for future downloads.")
                  status = 1
              else:
                  print("Par-check/repair disabled or no .par2 files found, and Unpack not required. Health is ok so handle as though download successful.")
                  print("Please check your Par-check/repair settings for future downloads.")

      if not os.path.isdir(os.environ["NZBPP_DIRECTORY"]):
          print("Nothing to post-process: destination directory", os.environ["NZBPP_DIRECTORY"], "doesn't exist. Setting status \"failed\".")
          status = 1

      if status == 1:
          sys.exit(NZBGET_POSTPROCESS_NONE)

      media_container = os.environ["NZBPO_MEDIAEXTENSIONS"].split(",")
      sample_ids = os.environ["NZBPO_SAMPLEIDS"].split(",")
      for dirpath, _, filenames in os.walk(os.environ["NZBPP_DIRECTORY"]):
          for file_name in filenames:
              file_path = os.path.join(dirpath, file_name)
              _, file_extension = os.path.splitext(file_name)
              if file_extension in media_container or ".*" in media_container:
                  if is_sample(file_path, os.environ["NZBPP_NZBNAME"], os.environ["NZBPO_MAXSAMPLESIZE"], sample_ids):
                      print("Deleting sample file:", file_path)
                      try:
                          os.unlink(file_path)
                      except:
                          print("Error: unable to delete file", file_path)
                          sys.exit(NZBGET_POSTPROCESS_ERROR)

      sys.exit(NZBGET_POSTPROCESS_SUCCESS)
    '';
  };
in {
  options.services.nzbget-wrapped = {
    enable = lib.mkEnableOption "NZBGet Usenet downloader with Caddy integration";
  };

  config = lib.mkIf config.services.nzbget-wrapped.enable {
    services.nzbget = {
      enable = true;
      settings = {
        # ensure downloaded files are group-writable (share group can process them)
        UMask = "0002";
        # disable built-in auth — Caddy / Pocket ID forward-auth is the gate
        ControlUsername = "";
        ControlPassword = "";
      };
    };

    systemd.tmpfiles.rules = [
      "d /var/lib/nzbget/scripts 2775 ${serviceUser} ${serviceGroup} -"
      "C /var/lib/nzbget/scripts/DeleteSamples.py 0755 ${serviceUser} ${serviceGroup} - ${deleteSamplesScript}"
    ];

    services.caddy-wrapper.virtualHosts."nzbget" = {
      inherit domain;
      forwardAuth = "127.0.0.1:4180";
      reverseProxy = "127.0.0.1:${toString port}";
    };
  };
}

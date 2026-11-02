{
  # journald otherwise keeps up to 4 GiB, which is more history than anyone
  # reads back and makes journalctl searches slow.
  services.journald.settings.Journal.SystemMaxUse = "1G";
}

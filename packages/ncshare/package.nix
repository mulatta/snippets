{
  coreutils,
  lib,
  nushell,
  pueue,
  rclone,
  writeTextFile,
}:

writeTextFile {
  name = "ncshare";
  destination = "/bin/ncshare";
  executable = true;

  text = ''
    #!${lib.getExe nushell}
    const CHMOD = "${lib.getExe' coreutils "chmod"}"
    const RCLONE = "${lib.getExe rclone}"
    const PUEUE = "${lib.getExe' pueue "pueue"}"
    const PUEUED = "${lib.getExe' pueue "pueued"}"

    ${builtins.readFile ./ncshare.nu}
  '';

  meta = {
    description = "Download password-protected Nextcloud public shares";
    license = lib.licenses.mit;
    mainProgram = "ncshare";
    platforms = lib.platforms.all;
  };
}

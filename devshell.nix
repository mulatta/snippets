{ pkgs }:

pkgs.mkShell {
  packages = with pkgs; [
    nushell
    pueue
    rclone
  ];
}

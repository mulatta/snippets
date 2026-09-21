{ pkgs }:

pkgs.mkShell {
  packages = [ pkgs.rclone ];
}

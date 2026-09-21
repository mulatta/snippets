def ensure-pueued [] {
  let status = do { ^$PUEUE status } | complete
  if $status.exit_code == 0 {
    return
  }

  # Capturing daemon output keeps pipe open in child and blocks forever.
  ^$PUEUED --daemonize out+err> /dev/null

  mut attempts = 0
  while $attempts < 20 {
    sleep 100ms
    let ready = do { ^$PUEUE status } | complete
    if $ready.exit_code == 0 {
      return
    }
    $attempts += 1
  }

  error make { msg: "pueued did not become ready" }
}

# Worker entry point used by pueue.
def "main __run-download" [config_dir: path, destination: path] {
  try {
    ^$RCLONE --config ($config_dir | path join "rclone.conf") copy ncshare: $destination --progress
  } catch {|error|
    rm --recursive --force $config_dir
    error make $error
  }

  rm --recursive --force $config_dir
}

def main [url_arg?: string, destination_arg?: path] {
  ensure-pueued

  let url = if $url_arg == null {
    input "Nextcloud URL: "
  } else {
    $url_arg
  }

  let normalized_url = $url | str trim | str replace --regex '/download/?$' '' | str replace --regex '/$' ''
  let parsed = $normalized_url | parse --regex '^https://(?<host>[A-Za-z0-9.-]+(?::[0-9]+)?)/s/(?<token>[A-Za-z0-9_-]+)$'

  if ($parsed | is-empty) {
    error make { msg: "Invalid Nextcloud share URL" }
  }

  let host = $parsed.0.host
  let token = $parsed.0.token
  let destination = if $destination_arg == null {
    let entered = input $"Destination [($env.PWD | path join 'download')]: "
    if ($entered | str trim | is-empty) {
      $env.PWD | path join "download"
    } else {
      $entered | path expand
    }
  } else {
    $destination_arg | path expand
  }

  let password = input --suppress-output "Password: "
  if ($password | is-empty) {
    error make { msg: "Password must not be empty" }
  }

  let obscured_password = $password | ^$RCLONE obscure - | str trim
  let config_dir = mktemp --directory --tmpdir ncshare.XXXXXXXX
  ^$CHMOD 700 $config_dir
  let config_file = $config_dir | path join "rclone.conf"

  [
    "[ncshare]"
    "type = webdav"
    $"url = https://($host)/public.php/webdav/"
    # Public shares use legacy WebDAV path; Nextcloud vendor mode rejects it as an account endpoint.
    "vendor = other"
    $"user = ($token)"
    $"pass = ($obscured_password)"
  ] | str join (char newline) | save $config_file
  ^$CHMOD 600 $config_file

  let label = $"ncshare-($token | str substring 0..7)"
  let result = try {
    ^$PUEUE add --label $label -- $env.CURRENT_FILE __run-download $config_dir $destination
  } catch {|error|
    rm --recursive --force $config_dir
    error make $error
  }

  print $result
  print "Monitor with: pueue status; pueue follow <task-id>"
}

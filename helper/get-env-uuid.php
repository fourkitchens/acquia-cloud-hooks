<?php
$acli = getenv('ACLI_COMMAND') ? getenv('ACLI_COMMAND') : "../../vendor/bin/acli -n";
if (isset($argc)) {
  if (isset($argv[1])) {
    $site_alias = $argv[1];
    $json = shell_exec($acli . " api:environments:find " . escapeshellarg($site_alias));
    $env_info = json_decode($json, TRUE);
    if (!empty($env_info) && !empty($env_info['id'])) {
      echo $env_info['id'];
    }
  }
}

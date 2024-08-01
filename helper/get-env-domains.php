<?php

$acli = getenv('ACLI_COMMAND') ? getenv('ACLI_COMMAND') : "../../vendor/bin/acli -n";
$hostnames = [];
if (isset($argc)) {
  if (isset($argv[1])) {
    $site_alias = $argv[1];
    $json = shell_exec($acli . " api:environments:domain-list " . escapeshellarg($site_alias));
    $domain_info = json_decode($json, TRUE);
    foreach ($domain_info as $domain) {
      if (!empty($domain['hostname'])) {
        if ($domain['flags']['active']) {
          $hostnames[] = $domain['hostname'];
        }
      }
    }
    echo implode(' ', $hostnames);
  }
}

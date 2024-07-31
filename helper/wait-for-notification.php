<?php
$max_timeout = getenv('ACLI_MAX_TIMEOUT') ? getenv('ACLI_MAX_TIMEOUT') : 600;
$delay = getenv('ACLI_DELAY') ? getenv('ACLI_DELAY') : 15;
$acli = getenv('ACLI_COMMAND') ? getenv('ACLI_COMMAND') : "../../vendor/bin/acli -n";
if (isset($argc)) {
  if (isset($argv[1])) {
    $message = 'Some Task';
    $json_filename = $argv[1];
    $json = json_decode(file_get_contents($json_filename), TRUE);
    if (!empty($json['_links']) && !empty($json['_links']['notification']) && !empty($json['_links']['notification']['href'])) {
      $notification_id = basename($json['_links']['notification']['href']);
      $message = $json['message'] ?? $message;
    }
    $start = time();
    do {
      sleep($delay);
      $notification_json = shell_exec($acli . ' api:notifications:find ' . $notification_id);
      $notification = json_decode($notification_json, TRUE);
      echo "Task: " . $message . "Progress: " . $notification['progress'] . "% Status: " . $notification['status'] . "\n";
    } while ($notification['status'] != 'completed' && ($start + $max_timeout) > time());
    if (($start + $max_timeout) > time()) {
      echo "Max Timeout Reached!!!\n";
    }
  }
}

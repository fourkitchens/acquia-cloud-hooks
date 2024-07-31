#!/bin/bash
#
# Cloud Hook (common): post-code-update
#
# The post-code-update hook runs in response to code commits.
# When you push commits to a Git branch, the post-code-update hooks runs for
# each environment that is currently running that branch. See
# ../README.md for details.
#
# Usage: post-code-update site target-env source-branch deployed-tag repo-url
#                         repo-type

site="$1"
target_env="$2"

# Do not interfere with the RA environment
if [ "$target_env" == "ra" ]; then
  exit
fi

# You must set up the following variables in
# /mnt/gfs/home/$site/$target_env/nobackup/bashkeys.sh
#
# - `ACQUIACLI_KEY`
#    Cloud API Private key generated when you generate a token.
#    See: https://docs.acquia.com/cloud-platform/develop/api/auth/#cloud-generate-api-token
# - `ACQUIACLI_SECRET`
#    Cloud API secret generated when you generate a token.

# `AH_REALM` should be provided by the acquia environment
# see: https://docs.acquia.com/acquia-cloud/develop/env-variable/#available-environment-variables
if [ -z "$AH_REALM" ]
then
  echo "The REALM is not set."
  exit 1;
fi

# Environment you wish to get grab backups from. Examples: prod, test, dev, ra
ACQUIA_CANONICAL_ENV="prod"
# The name of the primary database you want to back up when pushing to the
# canonical environment. This is USUALLY the same as the site's name.
ACQUIA_DATABASE_NAME="$site"

# Grab Keys
# @see https://docs.acquia.com/acquia-cloud/files/system-files/private
source /mnt/gfs/home/$site/$target_env/nobackup/bashkeys.sh

if [ -z "$ACQUIACLI_KEY" ] || [ -z "$ACQUIACLI_SECRET" ]
then
  echo "There are no keys set up for this environment."
  exit 1;
fi

if [ -f "/mnt/gfs/home/$site/$target_env/nobackup/skipbuild" ]; then
  echo "The skip file was detected. You must run backups and build commands manually."
  exit 0;
fi
PROJECT_ROOT="$( dirname "$0" )/../../.."
pushd "$PROJECT_ROOT" || exit 1
acli_path="$(realpath ./vendor/bin/acli)"
acli="$acli_path -n"
HELPER_SCRIPT_PATH="$( dirname "$0" )/../../helper"

# Login to the Acquia API.
$acli auth:login -k "$ACQUIACLI_KEY" -s "$ACQUIACLI_SECRET"

# If we aren't on the cononical env, pull in cononical's db and files
if [ "$target_env" != "$ACQUIA_CANONICAL_ENV" ]; then
  echo "Sync DB from $ACQUIA_CANONICAL_ENV to $target_env"
  TMP_FILE=$(mktemp --suffix=.json)
  $acli api:environments:database-copy "$site.$target_env" "$ACQUIA_DATABASE_NAME" "$site.$ACQUIA_CANONICAL_ENV" > "$TMP_FILE"
  ACLI_COMMAND="$acli" php "$HELPER_SCRIPT_PATH/wait-for-notification.php" "$TMP_FILE" &
  DB_PID=$!
  echo "Job running as pid: $DB_PID"

  echo "Sync files from $ACQUIA_CANONICAL_ENV to $target_env"
  CANONICAL_UUID="$( ACLI_COMMAND="$acli" php "$HELPER_SCRIPT_PATH/get-env-uuid.php" "$site.$ACQUIA_CANONICAL_ENV" )"
  if [ -z "$CANONICAL_UUID" ]; then
    echo "Couldn't sync over files because we couldn't get the canonical envs uuid."
  else
    TMP_FILE=$(mktemp --suffix=.json)
    $acli api:environments:file-copy "$site.$target_env" --source "$CANONICAL_UUID" > "$TMP_FILE"
    ACLI_COMMAND="$acli" php "$HELPER_SCRIPT_PATH/wait-for-notification.php" "$TMP_FILE"
    FILES_PID=$!
    echo "Job running as pid: $FILES_PID"
  fi
  wait $DB_PID
  wait $FILES_PID
else
  # Backing up current environment.
  echo "Backup $target_env DB"
  TMP_FILE=$(mktemp --suffix=.json)
  $acli api:environments:database-backup-create "$site.$target_env $ACQUIA_DATABASE_NAME" > "$TMP_FILE"
  ACLI_COMMAND="$acli" php "$HELPER_SCRIPT_PATH/wait-for-notification.php" "$TMP_FILE"
fi

popd || exit 1

echo "Starting Build for $target_env"

# Every environment builds like if it was production.

if [[ -f "$PROJECT_ROOT/scripts/custom/deploy.sh" ]]; then
echo "Running custom deployment script."
  "$PROJECT_ROOT/scripts/custom/deploy.sh" "$target_env"
else
  "$HELPER_SCRIPT_PATH/deploy.sh" "$target_env"
fi

echo "Ending Build for $target_env"

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

# Grab Keys
# @see https://docs.acquia.com/acquia-cloud-platform/manage-apps/files/system-files/private
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

popd || exit 1

echo "Starting Build for $target_env"

# Every environment builds like if it was production.

if [[ -f "$PROJECT_ROOT/scripts/custom/deploy.sh" ]]; then
echo "Running custom deployment script."
  "$PROJECT_ROOT/scripts/custom/deploy.sh" "$target_env"
else
  "$HELPER_SCRIPT_PATH/deploy.sh" "$target_env"
fi

pushd "$PROJECT_ROOT" || exit 1

echo "Finding domains that use Varnish."
DOMAINS="$( ACLI_COMMAND="$acli" php "$HELPER_SCRIPT_PATH/get-env-domains.php" "$site.$target_env" )"
echo "Clearing Varnish cache for $DOMAINS"
# DOMAINS is an argument list. Purposfully not quoting it.
TMP_FILE=$(mktemp --suffix=.json)
$acli api:environments:clear-caches "$site.$target_env" $DOMAINS > "$TMP_FILE"
ACLI_MAX_TIMEOUT=60 ACLI_DELAY=5 ACLI_COMMAND="$acli" php "$HELPER_SCRIPT_PATH/wait-for-notification.php" "$TMP_FILE"

popd || exit 1

echo "Ending Build for $target_env"

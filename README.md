# Acquia Cloud Hooks

Automated deployment hooks for Acquia Cloud Platform. These hooks run in response to code deployments and commits, handling database/file synchronization, Drupal deployment steps, and Varnish cache clearing.

## How It Works

Acquia Cloud Hooks are shell scripts that Acquia automatically executes when certain events occur in your environment. This package provides two hooks:

| Hook | Trigger | Script |
|---|---|---|
| `post-code-deploy` | A tag or branch is deployed to an environment | `common/post-code-deploy/build.sh` |
| `post-code-update` | A commit is pushed to a branch currently deployed to an environment | `common/post-code-update/build.sh` |

> **Note:** `common/post-code-update/build.sh` is a symlink pointing to `common/post-code-deploy/build.sh`. Both hooks run the exact same script — any changes made to `post-code-deploy/build.sh` are automatically reflected in `post-code-update`.

## What the Build Script Does

On each deployment, the build script:

1. **Skips the RA environment** — the Release Agent environment is always bypassed.
2. **Checks for a `skipbuild` file** — if present, exits immediately (see below).
3. **Authenticates** with the Acquia Cloud API via ACLI.
4. **Syncs data** from the canonical environment (default: `prod`):
   - On non-canonical environments: copies the database and files from `prod` (runs concurrently).
   - On the canonical environment: creates a database backup before deploying.
5. **Runs deployment commands** via `helper/deploy.sh` (or a custom script if one exists).
6. **Clears Varnish caches** for all active domains in the environment.

### Default Deploy Script

`helper/deploy.sh` runs the standard Drupal deployment sequence:

```
drush updatedb
drush cache-rebuild
drush config-import
drush config-import  (second pass)
drush cache-rebuild
```

### Custom Deploy Script

To override the default deploy steps, create `scripts/custom/deploy.sh` in your project root. If this file exists, it will be called instead of `helper/deploy.sh`.

## Setup

### 1. Install via Composer

```bash
composer require fourkitchens/acquia-cloud-hooks
```

### 2. Configure API Credentials

For each environment, create a `bashkeys.sh` file at the private file path:

```
/mnt/gfs/home/{site}/{environment}/nobackup/bashkeys.sh
```

The file must export your Acquia Cloud API credentials:

```bash
export ACQUIACLI_KEY="your-api-key"
export ACQUIACLI_SECRET="your-api-secret"
```

Generate API tokens at: https://docs.acquia.com/cloud-platform/develop/api/auth/#cloud-generate-api-token

### 3. Configuration Variables

The following variables can be adjusted at the top of `common/post-code-deploy/build.sh`:

| Variable | Default | Description |
|---|---|---|
| `ACQUIA_CANONICAL_ENV` | `prod` | Environment to sync database and files from |
| `ACQUIA_DATABASE_NAME` | `$site` | Database name to backup/copy |
| `ACLI_MAX_TIMEOUT` | `600` | Max seconds to wait for async API operations |
| `ACLI_DELAY` | `15` | Seconds between API status checks |

## Skipping a Build

To disable automated deployment for a specific environment without removing the hook, create an empty file at:

```
/mnt/gfs/home/{site}/{environment}/nobackup/skipbuild
```

**Example:**
```bash
touch /mnt/gfs/home/mysite/dev/nobackup/skipbuild
```

When this file is detected, the hook exits immediately with a message:

```
The skip file was detected. You must run backups and build commands manually.
```

All automated steps are skipped — no database sync, no file sync, no Drush commands, no Varnish clearing. The hook exits with code `0` so the deployment itself still succeeds.

To re-enable automated builds, delete the file:

```bash
rm /mnt/gfs/home/mysite/dev/nobackup/skipbuild
```

> **When to use `skipbuild`:** This is useful when you need to manually control a deployment — for example, when migrating data, running a complex update that requires manual steps, or temporarily disabling automation on a specific environment without affecting others.

## Dependencies

- [Acquia CLI (acli)](https://github.com/acquia/cli) — must be available at `vendor/bin/acli`
- [Drush](https://www.drush.org/) — must be available at `vendor/bin/drush`
- PHP — required for the helper scripts (`helper/*.php`)

## Helper Scripts

| Script | Purpose |
|---|---|
| `helper/deploy.sh` | Default Drupal deployment commands |
| `helper/get-env-uuid.php` | Retrieves an environment UUID via ACLI |
| `helper/get-env-domains.php` | Retrieves active domains for an environment |
| `helper/wait-for-notification.php` | Polls async Acquia API operations until completion |

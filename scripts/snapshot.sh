#!/usr/bin/env bash
#
# snapshot.sh — Capture current application state before deployment
#
# Usage: scripts/snapshot.sh <environment>
#
# Saves:
#   - Current git commit hash to storage/.last-good-deploy
#   - Database backup to storage/backups/pre-deploy-<timestamp>.sqlite
#   - Cleans up old backups (keeps last 10)

set -euo pipefail

ENVIRONMENT="${1:?Usage: snapshot.sh <staging|production>}"

case "$ENVIRONMENT" in
    staging)
        HOST="${STAGING_HOST:?STAGING_HOST not set}"
        USER="${STAGING_USER:?STAGING_USER not set}"
        APP_PATH="${STAGING_PATH:?STAGING_PATH not set}"
        SSH_KEY="${DEPLOY_KEY:?STAGING_DEPLOY_KEY not set}"
        ;;
    production)
        HOST="${PRODUCTION_HOST:?PRODUCTION_HOST not set}"
        USER="${PRODUCTION_USER:?PRODUCTION_USER not set}"
        APP_PATH="${PRODUCTION_PATH:?PRODUCTION_PATH not set}"
        SSH_KEY="${DEPLOY_KEY:?PRODUCTION_DEPLOY_KEY not set}"
        ;;
    *)
        echo "Error: environment must be 'staging' or 'production'"
        exit 1
        ;;
esac

echo "==> Creating snapshot of $ENVIRONMENT ($HOST)"

# Set up SSH
SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR"
if [ -n "$SSH_KEY" ]; then
    mkdir -p ~/.ssh
    echo "$SSH_KEY" > ~/.ssh/deploy_key
    chmod 600 ~/.ssh/deploy_key
    SSH_OPTS="$SSH_OPTS -i ~/.ssh/deploy_key"
fi

ssh_cmd() {
    ssh $SSH_OPTS "$USER@$HOST" "$@"
}

TIMESTAMP=$(date +%s)

# Save current commit
echo "==> Saving current commit hash"
ssh_cmd "cd $APP_PATH && git rev-parse HEAD > storage/.last-good-deploy"
CURRENT_COMMIT=$(ssh_cmd "cat $APP_PATH/storage/.last-good-deploy")
echo "    Commit: $CURRENT_COMMIT"

# Create backup directory
ssh_cmd "mkdir -p $APP_PATH/storage/backups"

# Backup SQLite database
echo "==> Backing up database"
ssh_cmd "cp $APP_PATH/database/database.sqlite $APP_PATH/storage/backups/pre-deploy-${TIMESTAMP}.sqlite 2>/dev/null" || echo "    No SQLite database to backup"

# Clean up old backups (keep last 10)
echo "==> Cleaning old backups (keeping last 10)"
ssh_cmd "cd $APP_PATH/storage/backups && ls -t pre-deploy-*.sqlite 2>/dev/null | tail -n +11 | xargs rm -f 2>/dev/null" || true

# Count backups
BACKUP_COUNT=$(ssh_cmd "ls $APP_PATH/storage/backups/pre-deploy-*.sqlite 2>/dev/null | wc -l" || echo "0")
echo "    Total backups: $BACKUP_COUNT"

echo "==> Snapshot complete"

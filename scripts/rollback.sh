#!/usr/bin/env bash
#
# rollback.sh — Rollback Clarabot to the last known good state
#
# Usage: scripts/rollback.sh <environment>
#   environment: staging | production
#
# Reads the last known good commit from storage/.last-good-deploy
# and restores the application to that state, including database.

set -euo pipefail

ENVIRONMENT="${1:?Usage: rollback.sh <staging|production>}"

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

echo "==> Rolling back $ENVIRONMENT ($HOST)"

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

echo "==> Enabling maintenance mode"
ssh_cmd "cd $APP_PATH && php artisan down --retry=60 --refresh=5" || true

# Read last known good commit
LAST_GOOD=$(ssh_cmd "cat $APP_PATH/storage/.last-good-deploy 2>/dev/null" || echo "")

if [ -z "$LAST_GOOD" ]; then
    echo "ERROR: No last-good-deploy snapshot found. Cannot auto-rollback."
    echo "       Manual intervention required."
    exit 1
fi

echo "==> Rolling back to commit: $LAST_GOOD"

# Restore code
echo "==> Restoring code"
ssh_cmd "cd $APP_PATH && git fetch origin && git reset --hard $LAST_GOOD"

# Restore database backup if available
BACKUP_FILE=$(ssh_cmd "ls -t $APP_PATH/storage/backups/pre-deploy-*.sqlite 2>/dev/null | head -1" || echo "")

if [ -n "$BACKUP_FILE" ]; then
    echo "==> Restoring database from backup: $BACKUP_FILE"
    ssh_cmd "cp $BACKUP_FILE $APP_PATH/database/database.sqlite"
else
    echo "==> No database backup found, attempting migration rollback"
    ssh_cmd "cd $APP_PATH && php artisan migrate:rollback --force" || true
fi

# Reinstall dependencies for the rolled-back version
echo "==> Reinstalling dependencies"
ssh_cmd "cd $APP_PATH && composer install --no-dev --no-interaction --prefer-dist --optimize-autoloader"

# Rebuild caches
echo "==> Rebuilding caches"
ssh_cmd "cd $APP_PATH && php artisan config:cache"
ssh_cmd "cd $APP_PATH && php artisan route:cache"
ssh_cmd "cd $APP_PATH && php artisan view:cache"

# Restart queue
echo "==> Restarting queue workers"
ssh_cmd "cd $APP_PATH && php artisan queue:restart"

# Bring app back up
echo "==> Disabling maintenance mode"
ssh_cmd "cd $APP_PATH && php artisan up"

# Verify health
echo "==> Verifying health after rollback"
HEALTH_URL=$(ssh_cmd "echo \${APP_URL:-http://localhost}")
HEALTH_STATUS=$(ssh_cmd "curl -s -o /dev/null -w '%{http_code}' $HEALTH_URL/up" || echo "000")

if [ "$HEALTH_STATUS" = "200" ]; then
    echo "==> Rollback successful. App is healthy."
else
    echo "WARNING: Health check returned $HEALTH_STATUS after rollback."
    echo "         Manual intervention may be required."
fi

echo "==> Rollback complete"
echo "    Restored to: $LAST_GOOD"
echo "    Time:        $(date -u +%Y-%m-%dT%H:%M:%SZ)"

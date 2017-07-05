#!/bin/bash
#
# This script is designed to be included in each DSDE Firecloud Jenkins deploy
# job so that we can have one standard way of doing deploys using
# docker-compose.  This script will fail if any of the environment variables
# referenced are not defined when this script starts up.
#

if [ -z "${SSHCMD}" ]; then
    echo "FATAL ERROR: SSHCMD undefined."
    exit 1
fi

if [ -z "${SSH_USER}" ]; then
    echo "FATAL ERROR: SSH_USER undefined."
    exit 2
fi

if [ -z "${SSH_HOST}" ]; then
    echo "FATAL ERROR: SSH_HOST undefined."
    exit 3
fi

if [ -z "${PROJECT}" ]; then
    echo "FATAL ERROR: PROJECT undefined."
    exit 4
fi

if [ -z "${COMPOSE_FILE}" ]; then
    echo "FATAL ERROR: COMPOSE_FILE undefined."
    exit 5
fi

if [ -z "${GITHUB_TOKEN}" ]; then
    echo "FATAL ERROR: GITHUB_TOKEN undefined."
    exit 6
fi

if [ -z "${ENV}" ]; then
    echo "FATAL ERROR: ENV undefined."
    exit 7
fi

if [ -z "${GIT_BRANCH}" ]; then
    echo "FATAL ERROR: GIT_BRANCH undefined."
    exit 8
fi

if [ -z "${GIT_REPO}" ]; then
    echo "FATAL ERROR: GIT_REPO undefined."
    exit 9
fi

if [ -z "${APP_REPO}" ]; then
    echo "FATAL ERROR: APP_REPO undefined."
    exit 10
fi

set -eux

### Configure ###
VAULT_TOKEN=$(sudo cat /etc/vault-token-dsde)
scp -v $SSHOPTS configure.rb $SSH_USER@$SSH_HOST:/tmp/configure.rb
BARE_GIT_BRANCH="${GIT_BRANCH#origin/}"
$SSHCMD $SSH_USER@$SSH_HOST "bash -c '" \
  "sudo VAULT_TOKEN=$VAULT_TOKEN GITHUB_TOKEN=$GITHUB_TOKEN" \
  " APP_NAME=$PROJECT ENV=$ENV OUTPUT_DIR=/app GIT_REPO=$GIT_REPO" GIT_BRANCH=$BARE_GIT_BRANCH \
  " /tmp/configure.rb -y" \
  "'"

#### Deploy ####

# Start new application container with the current version
$SSHCMD $SSH_USER@$SSH_HOST "docker pull $APP_REPO:$ENV"
$SSHCMD $SSH_USER@$SSH_HOST "docker-compose -p $PROJECT -f $COMPOSE_FILE stop"
$SSHCMD $SSH_USER@$SSH_HOST "docker-compose -p $PROJECT -f $COMPOSE_FILE rm -f"
$SSHCMD $SSH_USER@$SSH_HOST "docker-compose -p $PROJECT -f $COMPOSE_FILE up -d"

# Remove any dangling images that might be hanging around
$SSHCMD $SSH_USER@$SSH_HOST "docker images -aq --no-trunc --filter dangling=true | xargs docker rmi || /bin/true"

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

#### Create Directories for Sidecar Logging ####
if [[ -n ${CROMWELL_LOG_DIR} ]]; then
        $SSHCMD $SSH_USER@$SSH_HOST "if [[ ! -d ${CROMWELL_LOG_DIR} ]]; then sudo mkdir -p ${CROMWELL_LOG_DIR}; fi"
else
    echo "FATAL ERROR: env var CROMWELL_LOG_DIR is not defined."
    exit 10
fi

if [[ -n ${CROMWELL_LOG_POS_DIR} ]]; then
        $SSHCMD $SSH_USER@$SSH_HOST "if [[ ! -d ${CROMWELL_LOG_POS_DIR} ]]; then sudo mkdir -p ${CROMWELL_LOG_POS_DIR}; fi"
else
    echo "FATAL ERROR: env var CROMWELL_LOG_POS_DIR is not defined."
    exit 11
fi

#### Install Fluentd Package ####
if [[ ${PROJECT} == "mint" ]]; then
    $SSHCMD $SSH_USER@$SSH_HOST -t -o LogLevel=QUIET /bin/bash <<ENDSSH
echo "INFO-HOST_INFO: Checking for google-fluentd RPM on host ${SSH_HOST}..."
if rpm -ql google-fluentd >/dev/null 2>&1; then
    echo "INFO-PACKAGE_FOUND: Package google-fluentd is already installed."
else
    echo "INFO-PACKAGE_NOT_FOUND: google-fluentd"
    if [[ ! -f install-logging-agent.sh ]]; then
        echo "INFO-GETTING_SCRIPT_USING_CURL: install-logging-agent.sh"
        curl -sSO https://dl.google.com/cloudagents/install-logging-agent.sh
    fi
    if [[ -f install-logging-agent.sh ]]; then
        _dl_gce_fluentd_sha256sum="\$(sha256sum install-logging-agent.sh | awk '{ print \$1 }')"
        if [[ \${_dl_gce_fluentd_sha256sum} == ${GCE_FLUENTD_SHA256SUM} ]]; then
            echo "INFO-SHA256SUM_MATCH: install-logging-agent.sh"
            echo "INFO-EXECUTING_SCRIPT: install-logging-agent.sh"
            chmod 544 ./install-logging-agent.sh
            sudo bash -c './install-logging-agent.sh'
        else
            echo "ERROR-SHA256SUM_MISMATCH: install-logging-agent.sh"
        fi
    else
        echo "ERROR-FILE_NOT_FOUND: install-logging-agent.sh"
    fi
fi
ENDSSH
fi

#### Deploy ####

# Start new application container with the current version
$SSHCMD $SSH_USER@$SSH_HOST "docker-compose -p $PROJECT -f $COMPOSE_FILE  pull"
$SSHCMD $SSH_USER@$SSH_HOST "docker-compose -p $PROJECT -f $COMPOSE_FILE stop"
$SSHCMD $SSH_USER@$SSH_HOST "docker-compose -p $PROJECT -f $COMPOSE_FILE rm -f"
$SSHCMD $SSH_USER@$SSH_HOST "docker-compose -p $PROJECT -f $COMPOSE_FILE up -d"

# Remove any dangling images that might be hanging around
$SSHCMD $SSH_USER@$SSH_HOST "docker images -aq --no-trunc --filter dangling=true | xargs docker rmi || /bin/true"

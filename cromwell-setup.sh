#!/bin/bash
# v1.0 zarsky@broad

hash docker 2>/dev/null || {
    echo >&2 "It doesn't look like docker is installed. Install it from https://www.docker.com before continuing."; exit 1;
}

confirm () {
    # call with a prompt string or use a default
    read -r -p "${1:-Are you sure?} [y/N] " response
    case $response in
        [yY])
            shift
            $@
            ;;
        *)
            ;;
    esac
}

echo "To skip a step, just press return."

docker login

token_setup () {
    read -rp "Generate a github personal access token at https://github.com/settings/tokens with repo and read:org permissions and paste it here: " github_token
    echo $github_token > "$HOME/.github-token"
    docker run -it -e VAULT_ADDR='https://clotho.broadinstitute.org:8200' -v $HOME:/root:rw broadinstitute/dsde-toolbox vault auth -method=github token=$github_token
}
confirm "Set up github and vault tokens? " token_setup

clone_repos() {
    echo "Currently in" $PWD
    read -rp "Path to clone repos to (relative or absolute), if different: " repo_dir
    if [ ! -d $repo_dir ]
        then
        mkdir -p $repo_dir
    fi

    cd $repo_dir

    confirm "Clone CromIAM? " git clone https://github.com/broadinstitute/cromiam.git
}
confirm "Clone cromwell repos? " clone_repos

config () {
    if [[ $PWD == *"cromwell-develop"* ]]
        then
        cd ..
    fi
    cd $2
    APP_NAME=$1 \
    ENV=local \
    INPUT_DIR=../cromwell-develop \
    OUTPUT_DIR=config \
    ../cromwell-develop/configure.rb
    cd ..
}

read -rp "Name of cromiam repo, if not cromiam: " cromiam_dir
if [ ! $cromiam_dir ]
    then
    cromiam_dir=cromiam
fi
confirm "Set up CaaS? " config "caas" $cromiam_dir

echo "If you plan to run firecloud locally, run this command:"
echo "$ $(tput bold)sudo -s \"echo \\\"127.0.0.1       local.broadinstitute.org\\\" >> /etc/hosts\"$(tput sgr0)"
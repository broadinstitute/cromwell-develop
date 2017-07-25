render "cromiam.conf.ctmpl"
#render "cromwell.conf.ctmpl"
#render "cromwell-account.json.ctmpl"

copy_secret_from_path "secret/common/ca-bundle.crt", "chain"
copy_secret_from_path "secret/dsde/firecloud/#{$env}/common/server.key"
copy_secret_from_path "secret/dsde/firecloud/#{$env}/common/server.crt"

render "docker-rsync-local-caas.sh.ctmpl"
FileUtils.chmod 0755, "docker-rsync-local-caas.sh"
puts "\nRun ./config/docker-rsync-local-caas.sh to start the sam server.\n"
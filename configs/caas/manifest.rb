render "cromwell.conf.ctmpl"
render "cromiam.conf.ctmpl"
render "docker-compose.yaml.ctmpl"
render "cromwell-account.json.ctmpl"
render "sqlproxy.env.ctmpl"

# copy_secret_from_path "secret/dsde/caas/#{$env}/cromwell/cromwell-service-account.json", field = "private_key", output_file_name = "cromwell-account.pem"

copy_secret_from_path "secret/common/ca-bundle.crt", "chain"
copy_secret_from_path "secret/dsde/caas/#{$env}/common/server.key"
copy_secret_from_path "secret/dsde/caas/#{$env}/common/server.crt"

copy_file "stackdriver.conf"
copy_file "cromwell_log.conf"

render "cromwell.conf.ctmpl"
render "docker-compose.yaml.ctmpl"
render "cromwell-account.json.ctmpl"
render "htpasswd.users.ctmpl"

copy_secret_from_path "secret/dsde/mint/#{$env}/cromwell/cromwell-service-account.json", field = "private_key", output_file_name = "cromwell-account.pem"

copy_secret_from_path "secret/common/ca-bundle.crt", "chain"
copy_secret_from_path "secret/dsde/mint/#{$env}/common/server.key"
copy_secret_from_path "secret/dsde/mint/#{$env}/common/server.crt"

mysql = "secret/dsde/mint/#{$env}/cromwell/cromwell-mysql"
copy_secret_from_path mysql, field = "keystore", output_file_name = "keystore.b64"
base64decode "keystore.b64", "mysql01.jks"

copy_secret_from_path "secret/dsde/mint/#{$env}/cromwell/cromwell-mysql-trust", field = "value", output_file_name = "mysql_trust.jks.b64"
base64decode "mysql_trust.jks.b64", "mysql_trust.jks"

copy_file "site.conf"
copy_file "stackdriver.conf"
copy_file "cromwell_log.conf"

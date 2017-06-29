render "cromwell.conf.ctmpl"
render "cromiam.conf.ctmpl"
render "docker-compose.yaml.ctmpl"
render "cromwell-account.json.ctmpl"

copy_secret_from_path "secret/common/ca-bundle.crt", "chain"
copy_secret_from_path "secret/dsde/caas/#{$env}/common/server.key"
copy_secret_from_path "secret/dsde/caas/#{$env}/common/server.crt"

mysql = "secret/dsde/caas/#{$env}/cromwell/cromwell-mysql"
mysql_trust = "secret/dsde/caas/#{$env}/cromwell/cromwell-mysql-trust"

copy_secret_from_path mysql, field = "keystore", output_file_name = "keystore.b64"
base64decode "keystore.b64", "mysql01.jks"

copy_file_from_path mysql_trust, output_file_name = "mysql_trust.jks.b64"
base64decode "mysql_trust.jks.b64", "mysql_trust.jks"

copy_file "stackdriver.conf"
copy_file "cromwell_log.conf"

# cromwell-develop
Repository for cromwell configs

## Rendering Configs

To render the configs for a service, set the following environment variables:
* `APP_NAME` - one of the services in the configs directory (i.e. "cromwell")
* `ENV` - a deployment environment
* `OUTPUT_DIR` - directory to write configs to
* `VAULT_TOKEN` - If your cinfugration uses secrets, will need a vault token.  Defaults to token stored at `~/.vault-token`.

To run configure script:
```
ruby configure.rb -y
```

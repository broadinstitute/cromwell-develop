# cromwell-develop
Repository for cromwell configs

## Deprecation Notice

As of November 2024 the `caas` instance (Cromwell-as-a-Service) is no longer supported.
It was previously deployed in Google projects `broad-dsde-caas-dev`, `broad-dsde-caas-staging`, and `broad-dsde-caas-prod`.

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

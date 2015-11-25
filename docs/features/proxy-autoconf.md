# Feature

Provides proxy auto-configuration

## HTTP proxy
If http_proxy and/or https_proxy variables are defined then they are forwarded
to internal VM.

## No proxy
If no_proxy variable is provided then it is forwarded to internal VM.
File /etc/hosts is then use to add more entries to it.

## GIT proxy wrapper

If GIT_PROXY_COMMAND enviroment variable is provided, referenced script is
deployed and environment variable is configured.

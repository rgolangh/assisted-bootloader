#!/bin/bash 

curl -L https://github.com/rgolangh/assisted-bootloader/releases/download/v0.1.0/assisted-bootloader -o /var/tmp/assisted-bootloader
chmod +x /var/tmp/assisted-bootloader

/var/tmp/assisted-bootloader \
	-refresh-token-file /opt/token \
	-infra-env-id-file /opt/infraenvid

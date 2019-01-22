# Tarraform PAS and PKS for Azure

## CLI Install
```
$ cd /tmp

$ wget https://github.com/cloudfoundry/bosh-cli/releases/download/v5.4.0/bosh-cli-5.4.0-linux-amd64
$ sudo mv bosh-cli-* /usr/local/bin/bosh

$ wget https://github.com/pivotal-cf/om/releases/download/0.51.0/om-linux
$ sudo mv om-linux /usr/local/bin/om

$ wget https://github.com/pivotal-cf/pivnet-cli/releases/download/v0.0.55/pivnet-linux-amd64-0.0.55
$ sudo mv pivnet-linux* /usr/local/bin/pivnet

$ sudo chmod +x /usr/local/bin/bosh
$ sudo chmod +x /usr/local/bin/om
$ sudo chmod +x /usr/local/bin/pivnet

$ sudo apt update && sudo apt-get -y install jq
```
## OM
```
$ om --target https://pcf.mypcf.syanagihara.cf --skip-ssl-validation configure-authentication --username admin --password admin --decryption-passphrase admin
```

## BOSH
```
$ bosh alias-env azure -e 10.0.8.10 --ca-cert /var/tempest/workspaces/default/root_ca_certificate
```

## terraform.tfvars
- subscription_id = az account list|jq '.[].id' 
- tenant_id       = az account list|jq '.[].tenantId'
- client_id       = az ad sp list --display-name "Service Principal for BOSH by syanagihara" | jq '.[].appId'

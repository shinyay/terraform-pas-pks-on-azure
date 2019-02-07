# Tarraform PAS and PKS for Azure
## Jumpbox VM

### Create Resource Group
```
$ az group create --name jumpbox --location japaneast
```

### Create Virtual Machine
```
$ az vm create \
    --resource-group myResourceGroup \
    --name jumpbox \
    --image UbuntuLTS \
    --admin-username admin \
    --generate-ssh-keys
```

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
`terraform output` の結果から **ops_manager_ssh_private_key** の内容で `ops_man.pem` を作成

```
$ ssh -i ./ops_man.pem ubuntu@pcf.mypcf.syanagihara.cf
```

```
$ om --target https://pcf.mypcf.syanagihara.cf --skip-ssl-validation configure-authentication --username admin --password admin --decryption-passphrase admin
```

## BOSH
```
$ bosh alias-env azure -e 10.0.8.10 --ca-cert /var/tempest/workspaces/default/root_ca_certificate
```

## Azure Configuration
1. Install Azure CLI

```
$ brew install azure-cli
```

2. Set Cloud Name

```
$ az cloud set --name AzureCloud
```

- `AzureCloud`
- `AzureChinaCloud`
- `AzureUSGovernment`
- `AzureGermanCloud`

3. Login Azure

```
$ az login
```

4. Subscription ID

```
$ az account list|jq '.[].id'
```

5. Tenant ID

```
$ az account list|jq '.[].tenantId'
```

5. Set Subscription ID

```
$ az account set --subscription $SUBSCRIPTION
```

## terraform.tfvars
- subscription_id = az account list|jq '.[].id' 
- tenant_id       = az account list|jq '.[].tenantId'
- client_id       = az ad sp list --display-name "Service Principal for BOSH by syanagihara" | jq '.[].appId'

## PAS
### CERT DOMAIN
`*.mypcf.syanagihara.cf,*.sys.mypcf.syanagihara.cf,*.login.sys.mypcf.syanagihara.cf,*.uaa.sys.mypcf.syanagihara.cf,*.apps.mypcf.syanagihara.cf,*.iso.mypcf.syanagihara.cf`

## PIPELINE
```
set -x SUBSCRIPTION_ID <SUBSCRIPTION_ID>
set -x SERVICE_PRINCIPAL_PASSWORD <PASSWORD>
```

```
az ad app create --display-name "boshsyanagihara" --homepage "http://BOSHAzureCPI" --identifier-uris "http://BOSHsyanagihara" --password "$SERVICE_PRINCIPAL_PASSWORD" | tee app_create.json
```

```
set -x APP_ID $(jq -r .appId app_create.json)

az ad sp create --id $APP_ID

az role assignment create --assignee "http://BOSHsyanagihara" \
  --role "Contributor" \
  --scope /subscriptions/$SUBSCRIPTION_ID
```

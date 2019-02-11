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
    --admin-username azureuser \
    --generate-ssh-keys
```

### SSH to Virtual Machine
```
$ az vm list-ip-addresses|jq -r .[0].virtualMachine.network.publicIpAddresses[0].ipAddress
```

```
$ ssh azureuser@publicIpAddress
```

### [JumpBox] Install Azure CLI
```
$ sudo apt-get install apt-transport-https lsb-release software-properties-common dirmngr -y
$ AZ_REPO=$(lsb_release -cs)
$ echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ $AZ_REPO main" | \
    sudo tee /etc/apt/sources.list.d/azure-cli.list
$ sudo apt-key --keyring /etc/apt/trusted.gpg.d/Microsoft.gpg adv \
     --keyserver packages.microsoft.com \
     --recv-keys BC528686B50D79E339D3721CEB3E94ADBE1229CF
$ sudo apt-get update & apt-get install azure-cli
```

### [JumpBox] Download PAS
```
$ pivnet login --api-token='27f8.........'
$ pivnet product-files -p elastic-runtime -r 2.4.2
$ pivnet download-product-files -p elastic-runtime -r 2.4.2 -i 293808
```

### [JumpBox] Download Stemcell
```
$ pivnet releases -p stemcells-ubuntu-xenial
$ pivnet product-files -p stemcells-ubuntu-xenial -r 170.25
$ pivnet download-product-files -p stemcells-ubuntu-xenial -r 170.25 -i 303825
```

### [JumpBox] Create Azure Service Principal File
```
$ vim azure-credentials.json
```

```
{ "subscriptionID": "SUBSCRIPTION-ID", "tenantID": "TENANT-ID", "clientID": "SERVICE-PRINCIPAL-NAME", "clientSecret": "SERVICE-PRINCIPAL-PASSWORD" }
```

|Input|Command|
|-----|-------|
|SUBSCRIPTION-ID|az account list|jq -r '.[0].id'|
|TENANT-ID|az account list|jq -r '.[0].tenantId'|
|SERVICE-PRINCIPAL-NAME|az ad sp list --display-name boshsyanagihara | jq -r '.[0].appId'|
|SERVICE-PRINCIPAL-PASSWORD|Swordfish|

### [JumpBox] Terraform Installation

```
$ sudo snap install terraform
```

### [JumpBox] Create Azure Resources with Terraform
```
$ terraform init
$ terraform plan -out=plan
$ terraform apply plan
```

### [Option] Open port
```
$ az vm open-port --port 80 --resource-group jumpbox --name jumpbox
```

## BOSH Director for Azure
### Azure Config

|Input|Value|
|-----|-----|
|Subscription ID|cat terraform.tfstate \| jq -r .modules[0].outputs.subscription_id.value|
|Tenant ID|cat terraform.tfstate \| jq -r .modules[0].outputs.tenant_id.value|
|Application ID|cat terraform.tfstate \| jq -r .modules[0].outputs.client_id.value|
|Client Secret|cat terraform.tfstate \| jq -r .modules[0].outputs.client_secret.value|
|Resource Group Name|cat terraform.tfstate \| jq -r .modules[0].outputs.pcf_resource_group_name.value|
|BOSH Storage Account Name|cat terraform.tfstate \| jq -r .modules[0].outputs.bosh_root_storage_account.value|
|Storage Account Type|Premium_LRS|
|Default Security Group|cat terraform.tfstate \| jq -r .modules[0].outputs.bosh_deployed_vms_security_group_name.value|
|SSH Public Key|cat terraform.tfstate \| jq -r .modules[0].outputs.ops_manager_ssh_public_key.value|
|SSH Private Key|cat terraform.tfstate \| jq -r .modules[0].outputs.ops_manager_ssh_private_key.value|
|Azure Environment|Azure Commercial Cloud|

### Director Config

|Input|Value|
|-----|-----|
|NTP Servers|ntp.nict.jp|
|JMX Provider IP Address|---|
|Bosh HM Forwarder IP Address|---|
|Enable VM Resurrector Plugin|TRUE|
|Enable Post Deploy Scripts|TRUE|
|Recreate all VMs|TRUE|
|Recreate All Persistent Disks|TRUE|
|Enable bosh deploy retries|TRUE|
|Skip Director Drain Lifecycle|TRUE|
|Allow Legacy Agents|FALSE|
|Keep Unreachable Director VMs|FALSE|
|HM Pager Duty Plugin|FALSE|
|HM Email Plugin|FALSE|
|CredHub Encryption Provider|Internal|
|Blobstore Location|Internal|
|Enable TLS|TRUE|
|Database Location|Internal|
|Director Workers|5|
|Max Threads|---|
|Director Hostname|---|
|Custom SSH Banner|---|
|Identification Tags|---|

### Create Networks

|Input|Value|
|-----|-----|
|Enable ICMP checks|FALSE|
|Networks Name|Management|
|Management - Azure Network Name|NETWORK-NAME/SUBNET-NAME <br><br> NETWORK-NAME = cat terraform.tfstate \| jq -r .modules[0].outputs.network_name.value <br> SUBNET-NAME = cat terraform.tfstate \| jq -r .modules[0].outputs.management_subnet_name.value|
|Management - CIDR|cat terraform.tfstate \| jq -r .modules[0].outputs.management_subnet_cidrs.value[0]|
|Management - Reserved IP Ranges|cat terraform.tfstate \| jq -r .modules[0].outputs.management_subnet_cidrs.value[0]\|sed 's\|0/26$\|1\|g' <br> cat terraform.tfstate \| jq -r .modules[0].outputs.management_subnet_cidrs.value[0]\|sed 's\|0/26$\|9\|g'|
|Management - DNS|168.63.129.16|
|Management - Gateway|cat terraform.tfstate \| jq -r .modules[0].outputs.management_subnet_gateway.value|
|Networks Name|PAS|
|PAS - Azure Network Name|NETWORK-NAME/SUBNET-NAME <br><br> NETWORK-NAME = cat terraform.tfstate \| jq -r .modules[0].outputs.network_name.value <br> SUBNET-NAME = cat terraform.tfstate \| jq -r .modules[0].outputs.pas_subnet_name.value|
|PAS - CIDR|cat terraform.tfstate \| jq -r .modules[0].outputs.pas_subnet_cidrs.value[0]|
|PAS - Reserved IP Ranges|cat terraform.tfstate \| jq -r .modules[0].outputs.pas_subnet_cidrs.value[0]\|sed 's\|0/22$\|1\|g' <br> cat terraform.tfstate \| jq -r .modules[0].outputs.pas_subnet_cidrs.value[0]\|sed 's\|0/22$\|9\|g'|
|PAS - DNS|168.63.129.16|
|PAS - Gateway|cat terraform.tfstate \| jq -r .modules[0].outputs.pas_subnet_gateway.value|
|Networks Name|Services|
|Services - Azure Network Name|NETWORK-NAME/SUBNET-NAME <br><br> NETWORK-NAME = cat terraform.tfstate \| jq -r .modules[0].outputs.network_name.value <br> SUBNET-NAME = cat terraform.tfstate \| jq -r .modules[0].outputs.services_subnet_name.value|
|Services - CIDR|cat terraform.tfstate \| jq -r .modules[0].outputs.services_subnet_cidrs.value[0]|
|Services - Reserved IP Ranges|cat terraform.tfstate \| jq -r .modules[0].outputs.services_subnet_cidrs.value[0]\|sed 's\|0/22$\|1\|g' <br> cat terraform.tfstate \| jq -r .modules[0].outputs.services_subnet_cidrs.value[0]\|sed 's\|0/22$\|9\|g'|
|Services - DNS|168.63.129.16|
|Services - Gateway|cat terraform.tfstate \| jq -r .modules[0].outputs.services_subnet_gateway.value|

### Assign Networks

|Input|Value|
|-----|-----|
|Network|Management|

### Security

|Input|Value|
|-----|-----|
|Trusted Certificates|---|
|Generate VM passwords or use single password for all VMs|Generate passwords|

### BOSH DNS Config

|Input|Value|
|-----|-----|
|Excluded Recursors|---|
|Recursor Timeout|---|
|Handlers|[]|

### Syslog

|Input|Value|
|-----|-----|
|Do you want to configure Syslog for Bosh Director?|No|

### Resource Config

- DEFALUT

|Input|Value|
|-----|-----|
|BOSH Director|Standard_DS2_v2|
|Master Compilation Job|Standard_F4s|

## SSH to OpsMan VM from JumpBox
`terraform output` の結果から **ops_manager_ssh_private_key** の内容で `ops_man.pem` を作成

```
$ cat terraform.tfstate | jq -r .modules[0].outputs.ops_manager_ssh_private_key.value > ops_man.pem
$ chmod 600 ops_man.pem
```

```
$ ssh -i ./ops_man.pem ubuntu@pcf.mypcf.syanagihara.cf
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
### [JumpBox] Initial Configuration

- `OPS_MGR_DNS = cat terraform.tfstate | jq -r .modules[0].outputs.ops_manager_dns.value`
- `om --target https://$OPS_MGR_DNS --skip-ssl-validation configure-authentication --username $OPS_MGR_USR --password $OPS_MGR_PWD --decryption-passphrase $OPS_MGR_PWD`

```
$ om --target https://pcf.mypcf.syanagihara.cf --skip-ssl-validation configure-authentication --username admin --password admin --decryption-passphrase admin
```

### [JumpBox] Upload PAS Install Image

- `om --target https://$OPS_MGR_DNS -k -u $OPS_MGR_USR -p $OPS_MGR_PWD --request-timeout 3600 upload-product -p ~/$FILENAME`

```
$ om --target https://pcf.mypcf.syanagihara.cf -k -u admin -p admin --request-timeout 3600 upload-product -p ~/cf-2.4.2-build.33.pivotal
```

### [JumpBox] Upload Stemcell

- `om --target https://$OPS_MGR_DNS -k -u $OPS_MGR_USR -p $OPS_MGR_PWD --request-timeout 3600 upload-stemcell -p ~/$FILENAME`

```
$ om --target https://pcf.mypcf.syanagihara.cf -k -u admin -p admin --request-timeout 3600 upload-stemcell -s ~/bosh-stemcell-170.25-azure-hyperv-ubuntu-xenial-go_agent.tgz
```

### [JumpBox] Stage PAS

- `om --target https://$OPS_MGR_DNS -k -u $OPS_MGR_USR -p $OPS_MGR_PWD stage-product -p $PRODUCT_NAME -v $PRODUCT_VERSION`

```
$ om --target https://pcf.mypcf.syanagihara.cf -k -u admin -p admin stage-product -p cf -v 2.4.2
```

## PAS on Azure
### Assign Networks

|Input|Value|
|-----|-----|
|Network|PAS|

### Domains

|Input|Value|
|-----|-----|
|System Domain|cat terraform.tfstate \| jq -r .modules[0].outputs.sys_domain.value|
|Apps Domain|cat terraform.tfstate \| jq -r .modules[0].outputs.apps_domain.value|

### Networking

|Input|Value|
|-----|-----|
|Router IPs|---|
|SSH Proxy IPs|---|
|HAProxy IPs|---|
|TCP Router IPs|---|
|Certificates and Private Keys for HAProxy and Router Add|Add|
|Name|pas-cert|
|Generate RSA Certificate|MY_DOMAIN = cat terraform.tfstate \| jq -r .modules[2].outputs.dns_zone_name.value<br>\*.$MY_DOMAIN,\*.sys.$MY_DOMAIN,\*.apps.$MY_DOMAIN,login.sys.$MY_DOMAIN,uaa.sys.$MY_DOMAIN,doppler.sys.$MY_DOMAIN,loggregator.sys.$MY_DOMAIN,ssh.sys.$MY_DOMAIN,tcp.$MY_DOMAIN,opsman.$MY_DOMAIN<br>[SAMPLE]<br>\*.mypcf.syanagihara.cf,\*.sys.mypcf.syanagihara.cf,\*.apps.mypcf.syanagihara.cf,login.sys.mypcf.syanagihara.cf,uaa.sys.mypcf.syanagihara.cf,doppler.sys.mypcf.syanagihara.cf,loggregator.sys.mypcf.syanagihara.cf,ssh.sys.mypcf.syanagihara.cf,tcp.mypcf.syanagihara.cf,opsman.mypcf.syanagihara.cf|
|Certificate Authorities Trusted by Router and HAProxy|---|
|Minimum version of TLS supported by HAProxy and Router|TLSv1.2|
|Logging of Client IPs in CF Router|Log client IPs|
|Configure support for the X-Forwarded-Client-Cert header|TLS terminated for the first time at infrastructure load balancer|
|HAProxy behavior for Client Certificate Validation|HAProxy does not request client certificates.|
|Router behavior for Client Certificate Validation|Router requests but does not require client certificates.|
|HAProxy forwards requests to Router over TLS|Disable|
|HAProxy support for HSTS|Disable|
|Disable SSL certificate verification for this environment|TRUE|
|Disable HTTP on HAProxy and Router|FALSE|
|Disable insecure cookies on the Router|FALSE|
|Enable Zipkin tracing headers on the Router|TRUE|
|Enable Router to write access logs locally|TRUE|
|Routers reject requests for Isolation Segments|FALSE|
|Enable support for PROXY protocol in CF Router|FALSE|
|Choose whether to enable route services.|Enable route services|
|Max Connections Per Backend|500|
|Enable Keepalive Connections for Router|Enable|
|Router Timeout to Backends|900|
|Frontend Idle Timeout for Router and HAProxy|900|
|Load Balancer Unhealthy Threshold|20|
|Load Balancer Healthy Threshold|20|
|HTTP Headers to Log|---|
|HAProxy Request Max Buffer Size|16384|
|HAProxy Protected Domains|---|
|HAProxy Trusted CIDRs|---|
|Loggregator Port|---|
|Container Network Interface Plugin|Silk|
|DNS Search Domains|---|
|Database Connection Timeout|120|
|Enable TCP requests to your apps via specific ports on the TCP Router|Select this option if you prefer to enable TCP Routing at a later time|

### Application Containers

- Default

### Application Developer Controls

- Default

### Application Security Group

- Type **"X"** to acknowledge that you understand this message 



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
- client_id       = az ad sp list --display-name boshsyanagihara | jq -r '.[0].appId'

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

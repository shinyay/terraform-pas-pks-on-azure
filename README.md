# Tarraform PAS and PKS for Azure

## Azure CLI
### Install Azure CLI

```
$ brew install azure-cli
```

### Set Cloud Name

```
$ az cloud set --name AzureCloud
```

- `AzureCloud`
- `AzureChinaCloud`
- `AzureUSGovernment`
- `AzureGermanCloud`

### Login Azure

```
$ az login
```

### Azure ID

|ID Name|Command|
|-----|-------|
|SUBSCRIPTION-ID|az account list \| jq -r '.[0].id'|
|TENANT-ID|az account list \| jq -r '.[0].tenantId'|

### Set Subscription ID

```
$ az account set --subscription $SUBSCRIPTION
```

### Create Azure Active Directory (AAD) application

```
$ az ad app create --display-name "$AAD_APP_NAME" \
--password "$PASSWORD" --homepage "http://BOSHAzureCPI" \
--identifier-uris "$UNIQUE_IDENTIFY_URI"
```

|ID Name|Command|
|-----|-------|
|AAD_APP_NAME|Display Name on the List|
|PASSWORD|Password for AAD|
|UNIQUE_IDENTIFY_URI|Unique URI<br>ex. http://BOSHsyanagihara|


### Create Service Principal

```
$ az ad sp create --id $APPLICATION-ID
```

```
az role assignment create --assignee "SERVICE-PRINCIPAL-NAME" \
--role "Contributor" --scope /subscriptions/SUBSCRIPTION-ID
```

|ID Name|Command|
|-----|-------|
|APPLICATION-ID|az ad app list --display-name boshsyanagihara \| jq -r '.[0].appId'|
|SERVICE-PRINCIPAL-NAME|ANY<br>ex. az ad sp list --display-name boshsyanagihara \| jq -r '.[0].appId'|

## Jumpbox VM

### Create Resource Group

```
$ az group create --name jumpbox --location japaneast
```

### Create Virtual Machine

```
$ az vm create \
    --resource-group jumpbox \
    --name jumpbox \
    --image UbuntuLTS \
    --admin-username azureuser \
    --generate-ssh-keys
```

### [OPTION] Open Port 80 for Web Traffic

```
$ az vm open-port --port 80 --resource-group jumpbox --name jumpbox
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
sudo apt-get install apt-transport-https lsb-release software-properties-common dirmngr -y

AZ_REPO=$(lsb_release -cs)
echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ $AZ_REPO main" | \
    sudo tee /etc/apt/sources.list.d/azure-cli.list

sudo apt-key --keyring /etc/apt/trusted.gpg.d/Microsoft.gpg adv \
     --keyserver packages.microsoft.com \
     --recv-keys BC528686B50D79E339D3721CEB3E94ADBE1229CF

sudo apt-get update

sudo apt-get install azure-cli
```

### [JumpBox] Login Azure

```
$ az login --username $APPLICATION_ID --password $CLIENT_SECRET \
    --service-principal --tenant $TENANT_ID 
```

|ID Name|Command|
|-----|-------|
|APPLICATION-ID|az ad app list --display-name boshsyanagihara \| jq -r '.[0].appId'|
|CLIENT_SECRET|Password for AAD<br>ex. Swordfish|
|TENANT_ID|az account list \| jq -r '.[0].tenantId'|

### [JumpBox] Perform Registrations

```
$ az provider register --namespace Microsoft.Storage
$ az provider register --namespace Microsoft.Network
$ az provider register --namespace Microsoft.Compute
```

### [JumpBox][Option] Install Docker

```
$ sudo apt install apt-transport-https ca-certificates curl software-properties-common
$ curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
$ sudo apt-key fingerprint 0EBFCD88
$ sudo add-apt-repository \
    "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) \
      stable"
$ sudo apt update
$ sudo apt install -y docker-ce
$ sudo -i
# curl -L https://github.com/docker/compose/releases/download/1.6.2/docker-compose-`uname -s`-`uname -m` > /usr/local/bin/docker-compose
# chmod +x /usr/local/bin/docker-compose
# exit
```

### [JumpBox] Install　CLI

```
$ cd /tmp

$ sudo apt update

$ wget https://github.com/cloudfoundry/bosh-cli/releases/download/v5.5.1/bosh-cli-5.5.1-linux-amd64
$ sudo mv bosh-cli-* /usr/local/bin/bosh

$ wget https://github.com/pivotal-cf/om/releases/download/2.0.1/om-linux
$ sudo mv om-linux /usr/local/bin/om

$ wget https://github.com/pivotal-cf/pivnet-cli/releases/download/v0.0.60/pivnet-linux-amd64-0.0.60
$ sudo mv pivnet-linux* /usr/local/bin/pivnet

$ sudo chmod +x /usr/local/bin/bosh
$ sudo chmod +x /usr/local/bin/om
$ sudo chmod +x /usr/local/bin/pivnet

$ sudo apt-get -y install jq
$ sudo apt-get -y install unzip
$ sudo apt-get -y install tmux
```

### [JumpBox] Download PAS

```
$ pivnet login --api-token='27f8.........'
$ pivnet product -p elastic-runtime
$ pivnet product-files -p elastic-runtime -r 2.6.2

351857 | Azure Terraform Templates      | 0.40.0
428924 | Small Footprint PAS            | 2.6.2-build.2
428908 | Pivotal Application Service    | 2.6.2-build.2
```

```
$ pivnet download-product-files -p elastic-runtime -r 2.6.2 -i 351857
$ pivnet download-product-files -p elastic-runtime -r 2.6.2 -i 428908
```

### [JumpBox] Download Azure Service Broker

```
$ pivnet releases -p azure-service-broker
$ pivnet product-files -p azure-service-broker -r 1.11.0
$ pivnet accept-eula -p azure-service-broker -r 1.11.0
$ pivnet download-product-files -p azure-service-broker -r 1.11.0 -i 294549
```

### [JumpBox] Initial Configuration

- `export OPS_MGR_DNS=`terraform output -json| jq -r .ops_manager_dns.value``
- `om --target https://$OPS_MGR_DNS --skip-ssl-validation configure-authentication --username $OPS_MGR_USR --password $OPS_MGR_PWD --decryption-passphrase $OPS_MGR_PWD`

```
$ om --target https://pcf.mypcf.syanagihara.cf --skip-ssl-validation configure-authentication --username admin --password admin --decryption-passphrase admin
```

### [JumpBox] Upload PAS Install Image

- `om --target https://$OPS_MGR_DNS -k -u $OPS_MGR_USR -p $OPS_MGR_PWD --request-timeout 3600 upload-product -p ~/$FILENAME`

```
$ om --target https://pcf.mypcf.syanagihara.cf -k -u admin -p admin --request-timeout 3600 upload-product -p ~/cf-2.6.2-build.2.pivotal
```

### [JumpBox] Stage PAS

- `om --target https://$OPS_MGR_DNS -k -u $OPS_MGR_USR -p $OPS_MGR_PWD stage-product -p $PRODUCT_NAME -v $PRODUCT_VERSION`

```
$ om --target https://pcf.mypcf.syanagihara.cf -k -u admin -p admin stage-product -p cf -v 2.6.2
```

### [JumpBox] Download Stemcell

```
$ pivnet releases -p stemcells-ubuntu-xenial
$ pivnet product-files -p stemcells-ubuntu-xenial -r 170.25
$ pivnet download-product-files -p stemcells-ubuntu-xenial -r 170.25 -i 303825
```

### [JumpBox] Upload Stemcell Image

- `om --target https://$OPS_MGR_DNS -k -u $OPS_MGR_USR -p $OPS_MGR_PWD --request-timeout 3600 upload-stemcell -s ~/$STEMCELL`

```
$ om --target https://pcf.mypcf.syanagihara.cf -k -u admin -p admin --request-timeout 3600 upload-stemcell -s ~/bosh-stemcell-170.25-azure-hyperv-ubuntu-xenial-go_agent.tgz
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
|SUBSCRIPTION-ID|az account list \| jq -r '.[0].id'|
|TENANT-ID|az account list \| jq -r '.[0].tenantId'|
|SERVICE-PRINCIPAL-NAME|az ad sp list --display-name boshsyanagihara \| jq -r '.[0].appId'|
|SERVICE-PRINCIPAL-PASSWORD|Swordfish|

### [JumpBox] Terraform Installation

```
$ sudo snap install terraform
```

### [JumpBox] Create Azure Resources with Terraform

```
$ vim terraform.tfvars
```

```
subscription_id       = "YOUR-SUBSCRIPTION-ID"
tenant_id             = "YOUR-TENANT-ID"
client_id             = "YOUR-SERVICE-PRINCIPAL-ID"
client_secret         = "YOUR-SERVICE-PRINCIPAL-PASSWORD"

env_name              = "pcf"
env_short_name        = "az"
location              = "japaneast"
ops_manager_image_uri = "https://opsmanagersoutheastasia.blob.core.windows.net/images/ops-manager-2.6.4-build.166.vhd"
dns_suffix            = "syanagihara.cf"
vm_admin_username     = "admin"
```

```
$ terraform init
$ terraform plan -out=plan
$ terraform apply plan
```

### [JumpBox] Create DNS Record

```
$ terraform output -json | jq -r .env_dns_zone_name_servers.value
```

## BOSH Director for Azure

### Access Ops Manager

- https://OPS_MANAGER_DNS

```
$ terraform output -json | jq -r .ops_manager_dns.value
```

### Azure Config

|Input|Value|
|-----|-----|
|Subscription ID|terraform output -json \| jq -r .subscription_id.value|
|Tenant ID|terraform output -json \| jq -r .tenant_id.value|
|Application ID|terraform output -json \| jq -r .client_id.value|
|Client Secret|terraform output -json \| jq -r .client_secret.value|
|Resource Group Name|terraform output -json \| jq -r .pcf_resource_group_name.value|
|BOSH Storage Account Name|terraform output -json \| jq -r .bosh_root_storage_account.value|
|Storage Account Type|Premium_LRS|
|Default Security Group|terraform output -json \| jq -r .bosh_deployed_vms_security_group_name.value|
|SSH Public Key|terraform output -json \| jq -r .ops_manager_ssh_public_key.value|
|SSH Private Key|terraform output -json \| jq -r .ops_manager_ssh_private_key.value|
|Azure Environment|Azure Commercial Cloud|

### Director Config

|Input|Value|
|-----|-----|
|NTP Servers|0.jp.pool.ntp.org,1.jp.pool.ntp.org,2.jp.pool.ntp.org,3.jp.pool.ntp.org|
|Bosh HM Forwarder IP Address|---|
|Enable VM Resurrector Plugin|TRUE|
|Enable Post Deploy Scripts|TRUE|
|Recreate all VMs|TRUE|
|Recreate All Persistent Disks|TRUE|
|Enable bosh deploy retries|TRUE|
|Skip Director Drain Lifecycle|TRUE|
|Store BOSH Job Credentials on tmpfs (beta)|TRUE|
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

#### infrastructure

|Input|Value|
|-----|-----|
|Networks Name|infrastructure|
|infrastructure - Azure Network Name|NETWORK-NAME/SUBNET-NAME <br><br> NETWORK-NAME = terraform output -json\|jq -r .network_name.value <br> SUBNET-NAME = terraform output -json\|jq -r .management_subnet_name.value|
|infrastructure - CIDR|terraform output -json\|jq -r .management_subnet_cidrs.value[0]|
|infrastructure - Reserved IP Ranges|terraform output -json\|jq -r .management_subnet_cidrs.value[0]\|sed 's\|0/26$\|1\|g' <br> terraform output -json\|jq -r .management_subnet_cidrs.value[0]\|sed 's\|0/26$\|9\|g'|
|infrastructure - DNS|168.63.129.16|
|infrastructure - Gateway|terraform output -json\|jq -r .infrastructure_subnet_gateway.value|

#### pas

|Input|Value|
|-----|-----|
|Networks Name|pas|
|pas - Azure Network Name|NETWORK-NAME/SUBNET-NAME <br><br> NETWORK-NAME = terraform output -json\|jq -r .network_name.value <br> SUBNET-NAME = terraform output -json\|jq -r .pas_subnet_name.value|
|pas - CIDR|terraform output -json\|jq -r .pas_subnet_cidrs.value[0]|
|pas - Reserved IP Ranges|terraform output -json\|jq -r .pas_subnet_cidrs.value[0]\|sed 's\|0/22$\|1\|g' <br> terraform output -json\|jq -r .pas_subnet_cidrs.value[0]\|sed 's\|0/22$\|9\|g'|
|pas - DNS|168.63.129.16|
|pas - Gateway|terraform output -json\|jq -r .pas_subnet_gateway.value|

#### services

|Input|Value|
|-----|-----|
|Networks Name|services|
|services - Azure Network Name|NETWORK-NAME/SUBNET-NAME <br><br> NETWORK-NAME = terraform output -json\|jq -r .network_name.value <br> SUBNET-NAME = terraform output -json\|jq -r .services_subnet_name.value|
|services - CIDR|terraform output -json\|jq -r .services_subnet_cidrs.value[0]|
|services - Reserved IP Ranges|terraform output -json\|jq -r .services_subnet_cidrs.value[0]\|sed 's\|0/22$\|1\|g' <br> terraform output -json\|jq -r .services_subnet_cidrs.value[0]\|sed 's\|0/22$\|9\|g'|
|services - DNS|168.63.129.16|
|services - Gateway|terraform output -json\|jq -r .services_subnet_gateway.value|

### Assign Networks

|Input|Value|
|-----|-----|
|Network|infrastructure|

### Security

- DEFALUT

|Input|Value|
|-----|-----|
|Trusted Certificates|---|
|Generate VM passwords or use single password for all VMs|Generate passwords|

### BOSH DNS Config

- DEFALUT

|Input|Value|
|-----|-----|
|Excluded Recursors|---|
|Recursor Timeout|---|
|Handlers|[]|

### Syslog

- DEFALUT

|Input|Value|
|-----|-----|
|Do you want to configure Syslog for Bosh Director?|No|

### Resource Config

- DEFALUT

|Input|Value|
|-----|-----|
|BOSH Director|Standard_DS2_v2|
|Master Compilation Job|Standard_F4s|



## PAS on Azure
### Assign Networks

|Input|Value|
|-----|-----|
|Network|pas|

### Domains

|Input|Value|
|-----|-----|
|System Domain|terraform output -json\|jq -r .sys_domain.value|
|Apps Domain|terraform output -json\|jq -r .apps_domain.value|

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
|Minimum version of TLS supported by HAProxy and Router|DEFAUT<br>TLSv1.2|
|Logging of Client IPs in CF Router|DEFAULT<br>Log client IPs|
|Configure support for the X-Forwarded-Client-Cert header|DEFAUT<br>TLS terminated for the first time at infrastructure load balancer|
|HAProxy behavior for Client Certificate Validation|DEFAUT<br>HAProxy does not request client certificates.|
|Router behavior for Client Certificate Validation|DEFAUT<br>Router requests but does not require client certificates.|
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

### Authentication and Enterprise SSO

- Default

### UAA

|Input|Value|
|-----|-----|
|Choose the location of your UAA database|PAS database (configured on the Databases pane)
|JWT Issuer URI|---|
|SAML Service Provider Credentials|Generate RSA Certificate|
|Generate RSA Certificate|MY_DOMAIN = cat terraform.tfstate \| jq -r .modules[2].outputs.dns_zone_name.value<br>\*.$MY_DOMAIN,\*.sys.$MY_DOMAIN,\*.apps.$MY_DOMAIN,login.sys.$MY_DOMAIN,uaa.sys.$MY_DOMAIN,doppler.sys.$MY_DOMAIN,loggregator.sys.$MY_DOMAIN,ssh.sys.$MY_DOMAIN,tcp.$MY_DOMAIN,opsman.$MY_DOMAIN<br>[SAMPLE]<br>\*.mypcf.syanagihara.cf,\*.sys.mypcf.syanagihara.cf,\*.apps.mypcf.syanagihara.cf,login.sys.mypcf.syanagihara.cf,uaa.sys.mypcf.syanagihara.cf,doppler.sys.mypcf.syanagihara.cf,loggregator.sys.mypcf.syanagihara.cf,ssh.sys.mypcf.syanagihara.cf,tcp.mypcf.syanagihara.cf,opsman.mypcf.syanagihara.cf|
|SAML Service Provider Key Password|---|
|SAML Entity ID Override|---|
|Signature Algorithm|SHA256|
|Apps Manager Access Token Lifetime|3600|
|Apps Manager Refresh Token Lifetim|3600|
|Cloud Foundry CLI Access Token Lifetime|7200|
|Cloud Foundry CLI Refresh Token Lifetime|1209600|
|Global Login Session Max Timeout|28800|
|Global Login Session Idle Timeout|1800|
|Customize Username Label|Email|
|Customize Password Label|Password|
|Proxy IPs Regular Expression|DEFAULT|

### CredHub

|Input|Value|
|-----|-----|
|Choose the location of your CredHub database|PAS database|
|Encryption Keys|Add|
|Name|pas-encrypt|
|Key|<20字以上>|
|Primary|TRUE|

### Databases

- Internal Databases - MySQL - Percona XtraDB Cluster

### Internal MySQL

- E-mail address (required) 

### File Storage

- Default

### System Logging

- Default

### Custom Branding

- Default

### Apps Manager

- Default

### Email Notifications

- Default

### App Autoscaler

- Default

### Cloud Controller

- Default

### Smoke Tests

- Default

### Advanced Features

- Default

### Metric Registrar

- Default

### Errands

- Default

### Resource Config

|Input|Value|
|-----|-----|
|Router - LoadBalancers|terraform output -json\| jq -r .web_lb_name.value|
|Diego Brain|terraform output -json\| jq -r .diego_ssh_lb_name.value|

---
## Azure Service Broker
### Service Broker Database
#### NodeJS

```
$ sudo apt install -y nodejs npm
$ sudo npm install n -g
$ sudo n stable
$ sudo apt purge -y nodejs npm
$ exec $SHELL -l
$ node -v
```

#### CF CLI

```
$ wget -q -O - https://packages.cloudfoundry.org/debian/cli.cloudfoundry.org.key | sudo apt-key add -
$ echo "deb https://packages.cloudfoundry.org/debian stable main" | sudo tee /etc/apt/sources.list.d/cloudfoundry-cli.list
$ sudo apt-get update
$ sudo apt-get install cf-cli
```

#### Azure SQL Database

```
$ az sql server create --name service-broker-svr --resource-group pcf --location japaneast  --admin-user admin  --admin-password ChangeYourAdminPassword1
$ az sql server firewall-rule create --resource-group pcf --server service-broker-svr -n AllowAll --start-ip-address 0.0.0.0 --end-ip-address 255.255.255.255
$ az sql db create --resource-group pcf --server service-broker-svr --name azure-broker-db
```

```
$ sudo npm install -g sql-cli
$ mssql --server "service-broker-svr.database.windows.net" --database azure-broker-db --user admin@service-broker-svr --pass ChangeYourAdminPassword1 --encrypt
```

```
CREATE TABLE instances (azureInstanceId varchar(256) NOT NULL UNIQUE, status varchar(18), timestamp DATETIME DEFAULT (GETDATE()), instanceId char(36) PRIMARY KEY, serviceId char(36) NOT NULL, planId char(36) NOT NULL, organizationGuid char(36) NOT NULL, spaceGuid char(36) NOT NULL, parameters text, lastOperation text, provisioningResult text);
ALTER TABLE instances ADD state text;
CREATE TABLE bindings (bindingId char(36) PRIMARY KEY, instanceId char(36) FOREIGN KEY REFERENCES instances(instanceId), timestamp DATETIME DEFAULT (GETDATE()), serviceId char(36) NOT NULL, planId char(36) NOT NULL, parameters text, bindingResult text);
```

#### Deploy the meta Azure service broker

```
$ git clone https://github.com/Azure/meta-azure-service-broker
$ cd meta-azure-service-broker
```

```
$ vim manifest.yml

---
applications:
- name: meta-azure-service-broker
  buildpack: nodejs_buildpack
  instances: 1
  env:
    ENVIRONMENT: AzureCloud
    SUBSCRIPTION_ID: <cat terraform.tfstate | jq -r .modules[0].outputs.subscription_id.value>
    TENANT_ID: <cat terraform.tfstate | jq -r .modules[0].outputs.tenant_id.value>
    CLIENT_ID: <cat terraform.tfstate | jq -r .modules[0].outputs.client_id.value>
    CLIENT_SECRET: <cat terraform.tfstate | jq -r .modules[0].outputs.client_secret.value>
    SECURITY_USER_NAME: asb-http-auth
    SECURITY_USER_PASSWORD: VeryStrongHTTPPassword!

    SPACE_SCOPING_ENABLED: false

    AZURE_BROKER_DATABASE_PROVIDER: sqlserver
    AZURE_BROKER_DATABASE_SERVER: service-broker-svr.database.windows.net
    AZURE_BROKER_DATABASE_USER: admin
    AZURE_BROKER_DATABASE_PASSWORD: ChangeYourAdminPassword1
    AZURE_BROKER_DATABASE_NAME: azure-broker-db
    AZURE_BROKER_DATABASE_ENCRYPTION_KEY: bcOdllFpg16kwvMVardg37GEETeeTKw0

    AZURE_SQLDB_ALLOW_TO_CREATE_SQL_SERVER: true
    AZURE_SQLDB_ENABLE_TRANSPARENT_DATA_ENCRYPTION: false
    AZURE_SQLDB_SQL_SERVER_POOL: '[
      {
        "resourceGroup": "pcf",
        "location": "japaneast",
        "sqlServerName": "service-broker-svr",
        "administratorLogin": "admin",
        "administratorLoginPassword": "ChangeYourAdminPassword1"
      }
    ]'
```

- AZURE_BROKER_DATABASE_ENCRYPTION_KEY

````
$ cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1
````

##### Edit .npmrc for CF Environment

```
$ vim .npmrc
```

- Remove `offline=true` in the .npmrc

#### Install Node dependencies for production environment

```
$ export NODE_ENV=production
$ sudo npm install
```

#### CF PUSH

```
$ cf login -a api.sys.mypcf.syanagihara.cf --skip-ssl-validation
$ cf push
```

```
    :
    :
    :
   underscore@1.4.4 /tmp/app/node_modules/azure-storage/node_modules/underscore
   validator@3.22.2 /tmp/app/node_modules/azure-storage/node_modules/validator
   mocha@3.3.0 /tmp/app/node_modules/mocha
   commander@2.9.0 /tmp/app/node_modules/mocha/node_modules/commander
   debug@2.6.0 /tmp/app/node_modules/mocha/node_modules/debug
   ms@0.7.2 /tmp/app/node_modules/mocha/node_modules/ms
   diff@3.2.0 /tmp/app/node_modules/mocha/node_modules/diff
   glob@7.1.1 /tmp/app/node_modules/mocha/node_modules/glob
   supports-color@3.1.2 /tmp/app/node_modules/mocha/node_modules/supports-color
   has-flag@1.0.0 /tmp/app/node_modules/mocha/node_modules/has-flag
          Installing any new modules (package.json + package-lock.json)
   audited 4920 packages in 5.694s
   found 373 vulnerabilities (10 low, 298 moderate, 64 high, 1 critical)
     run `npm audit fix` to fix them, or `npm audit` for details
   Exit status 0
   Uploading droplet, build artifacts cache...
   Uploading droplet...
   Uploading build artifacts cache...
   Uploaded build artifacts cache (223B)
   Uploaded droplet (47.5M)
   Uploading complete
   Cell 6867476b-0757-401c-b122-f10790327e89 stopping instance c291e471-b752-4529-a20c-27b787677ebb
   Cell 6867476b-0757-401c-b122-f10790327e89 destroying container for instance c291e471-b752-4529-a20c-27b787677ebb

Waiting for app to start...

name:              meta-azure-service-broker
requested state:   started
routes:            meta-azure-service-broker.apps.mypcf.syanagihara.cf
last uploaded:     Thu 07 Mar 11:11:41 UTC 2019
stack:             cflinuxfs3
buildpacks:        nodejs

type:            web
instances:       1/1
memory usage:    1024M
start command:   npm start
     state     since                  cpu    memory         disk           details
#0   running   2019-03-07T11:12:02Z   0.0%   177.9M of 1G   329.6M of 1G
```

#### Register a service broker

```
$ cf create-service-broker demo-service-broker asb-http-auth VeryStrongHTTPPassword! http://meta-azure-service-broker.apps.mypcf.syanagihara.cf
```

#### Enable Azure Services

```
$ cf enable-service-access azure-cosmosdb
$ cf enable-service-access azure-eventhubs
$ cf enable-service-access azure-mysqldb
$ cf enable-service-access azure-postgresqldb
$ cf enable-service-access azure-rediscache
$ cf enable-service-access azure-servicebus
$ cf enable-service-access azure-sqldb
$ cf enable-service-access azure-sqldb-failover-group
$ cf enable-service-access azure-storage
```

```
$ cf marketplace
Getting services from marketplace in org system / space development as admin...
OK

service                      plans                                                                                                                                                                                                                                     description                                     broker
app-autoscaler               standard                                                                                                                                                                                                                                  Scales bound applications in response to load   app-autoscaler
azure-cosmosdb               standard                                                                                                                                                                                                                                  Azure CosmosDb Service                          demo-service-broker
azure-eventhubs              basic, standard                                                                                                                                                                                                                           Azure Event Hubs Service                        demo-service-broker
azure-mysqldb                basic1, basic2                                                                                                                                                                                                                            Azure Database for MySQL Service                demo-service-broker
azure-postgresqldb           basic1, basic2, generalpurpose2, generalpurpose4, generalpurpose8, generalpurpose16, generalpurpose32, generalpurpose64, memoryoptimized2, memoryoptimized4, memoryoptimized8, memoryoptimized16, memoryoptimized32                       Azure Database for PostgreSQL Service           demo-service-broker
azure-rediscache             basicc0, basicc1, basicc2, basicc3, basicc4, basicc5, basicc6, standardc0, standardc1, standardc2, standardc3, standardc4, standardc5, standardc6, premiump1, premiump2, premiump3, premiump4                                             Azure Redis Cache Service                       demo-service-broker
azure-servicebus             basic, standard, premium                                                                                                                                                                                                                  Azure Service Bus Service                       demo-service-broker
azure-sqldb                  basic, StandardS0, StandardS1, StandardS2, StandardS3, StandardS4, StandardS6, StandardS7, StandardS9, StandardS12, PremiumP1, PremiumP2, PremiumP4, PremiumP6, PremiumP11, PremiumP15, DataWarehouse100, DataWarehouse1200, Registered   Azure SQL Database Service                      demo-service-broker
azure-sqldb-failover-group   SecondaryDatabaseWithFailoverGroup, ExistingDatabaseInFailoverGroup                                                                                                                                                                       Azure SQL Database Failover Group Service       demo-service-broker
azure-storage                standard                                                                                                                                                                                                                                  Azure Storage Service                           demo-service-broker

TIP: Use 'cf marketplace -s SERVICE' to view descriptions of individual plans of a given service.
```

### Azure Service Broker Tile

#### Azure Config

|Input|Value|
|-----|-----|
|Azure Environment|Azure Cloud|
|Subscription Id|cat terraform.tfstate \| jq -r .modules[0].outputs.subscription_id.value|
|Tenant Id|cat terraform.tfstate \| jq -r .modules[0].outputs.tenant_id.value|
|Client Id|cat terraform.tfstate \| jq -r .modules[0].outputs.client_id.value|
|Client Secret|cat terraform.tfstate \| jq -r .modules[0].outputs.client_secret.value|

#### Broker Config

|Input|Value|
|-----|-----|
|Database Provider|SQL Database|
|Database Server|service-broker-svr.database.windows.net|
|Database Username|admin|
|Database Password|ChangeYourAdminPassword1|
|Database Name|azure-broker-db|
|Database Encryption Key|bcOdllFpg16kwvMVardg37GEETeeTKw0|

#### SQL Database Config

|Input|Value|
|-----|-----|
|Resource Group of the SQL Server|pcf|
|Location of the SQL Server|japaneast|
|SQL Server Name|service-broker-svr|
|SQL Server Administrator Login|admin|
|SQL Server Administrator Login Password|ChangeYourAdminPassword1|

#### Apply Changes

- Installation Dashboard
  - Review Pending Changes
    - Apply Changes

### Using Azure Service Broker

#### List Services

- `cf marketplace`

```
service                      plans                                                                                                                                                                                                                                     description                                     broker
app-autoscaler               standard                                                                                                                                                                                                                                  Scales bound applications in response to load   app-autoscaler
azure-cosmosdb               standard                                                                                                                                                                                                                                  Azure CosmosDb Service                          demo-service-broker
azure-documentdb             standard                                                                                                                                                                                                                                  Azure DocumentDb Service                        demo-service-broker
azure-eventhubs              basic, standard                                                                                                                                                                                                                           Azure Event Hubs Service                        demo-service-broker
azure-mysqldb                basic1, basic2                                                                                                                                                                                                                            Azure Database for MySQL Service                demo-service-broker
azure-postgresqldb           basic1, basic2, generalpurpose2, generalpurpose4, generalpurpose8, generalpurpose16, generalpurpose32, generalpurpose64, memoryoptimized2, memoryoptimized4, memoryoptimized8, memoryoptimized16, memoryoptimized32                       Azure Database for PostgreSQL Service           demo-service-broker
azure-rediscache             basicc0, basicc1, basicc2, basicc3, basicc4, basicc5, basicc6, standardc0, standardc1, standardc2, standardc3, standardc4, standardc5, standardc6, premiump1, premiump2, premiump3, premiump4                                             Azure Redis Cache Service                       demo-service-broker
azure-servicebus             basic, standard, premium                                                                                                                                                                                                                  Azure Service Bus Service                       demo-service-broker
azure-sqldb                  basic, StandardS0, StandardS1, StandardS2, StandardS3, StandardS4, StandardS6, StandardS7, StandardS9, StandardS12, PremiumP1, PremiumP2, PremiumP4, PremiumP6, PremiumP11, PremiumP15, DataWarehouse100, DataWarehouse1200, Registered   Azure SQL Database Service                      demo-service-broker
azure-sqldb-failover-group   SecondaryDatabaseWithFailoverGroup, ExistingDatabaseInFailoverGroup                                                                                                                                                                       Azure SQL Database Failover Group Service       demo-service-broker
azure-storage                standard                                                                                                                                                                                                                                  Azure Storage Service                           demo-service-broker
```

---

## Memo/Tips

### Ops Manager VM Login

```
$ az vm list-ip-addresses --resource-group pcf -n pcf-ops-manager-vm| jq -r .[].virtualMachine.network.publicIpAddresses[].ipAddress
$ terraform output -json | jq -r .ops_manager_ssh_private_key.value > pcf.key
$ chmod 600 pcf.key
$ ssh -i pcf.key ubuntu@OPS-MANAGER-PUBLIC-IP
```

- Check OpsManager FQDN by Azure Porta
- Create Private Key for OpsManager VM
  - `$ terraform output -json | jq -r .ops_manager_ssh_private_key.value`
- Change the permissions for your SSH private key
  - `$ chmod 600 PRIVATE-KEY`
- SSH into the Ops Manager VM
  - `$ ssh -i PRIVATE-KEY ubuntu@OPS-MANAGER-FQDN`

### BOSH CLI
```
$ bosh alias-env azure -e $BOSH_DIRECTOR_IP --ca-cert /var/tempest/workspaces/default/root_ca_certificate
$ bosh -e azure log-in
  <director/director-credential>
$ bosh -e azure vms
$ bosh -e azure -d $DEPLOYMENT ssh $VMNAME/$GUID
$ bosh -e azure -d $DEPLOYMENT cloud-check
$ bosh -e azure -d $DEPLOYMENT stop --hard
$ find /var/tempest/workspaces/default/deployments -name cf-*.yml
$ bosh -e azure -d $DEPLOYMENT start
```

### Kernel Panic
```
$ sudo su -
# sudo sh -c 'echo 1 > /proc/sys/kernel/sysrq'
# sudo sh -c 'echo c > /proc/sysrq-trigger'
```

### UAA for usage_service.audit

- UAA Target

```
$ uaac target uaa.sys.pcf.syanagihara.cf --skip-ssl-validation
Unknown key: Max-Age = 86400

Target: https://uaa.sys.pcf.syanagihara.cf
```

- UAA Credential
  - PAS -> Credentials -> UAA -> Admin Client Credentials


```
$ uaac token client get admin -s ADMIN-CLIENT-CREDENTIAL
```

- User Add

```
$ uaac user add syanagihara -p PASSWORD --emails syanagihara@example.com
user account successfully added
```

```
$ uaac member add usage_service.audit syanagihara
```

- [Reference](https://docs.pivotal.io/pivotalcf/2-6/opsguide/accounting-report.html)

```
$ curl "https://app-usage.YOUR-SYSTEM-DOMAIN/system_report/app_usages" -k -v -H "authorization: `cf oauth-token`"

$ curl "https://app-usage.YOUR-SYSTEM-DOMAIN/system_report/task_usages" -k -v -H "authorization: `cf oauth-token`"

$ curl "https://app-usage.YOUR-SYSTEM-DOMAIN/system_report/service_usages" -k -v -H "authorization: `cf oauth-token`"

$ curl "https://app-usage.YOUR-SYSTEM-DOMAIN/organizations/`cf org YOUR-ORG --guid`/app_usages?start=YYYY-MM-DD&end=YYYY-MM-DD" -k -v -H "authorization: `cf oauth-token`"

$ curl "https://app-usage.YOUR-SYSTEM-DOMAIN/organizations/`cf org YOUR-ORG --guid`/task_usages?start=YYYY-MM-DD&end=YYYY-MM-DD" -k -v -H "authorization: `cf oauth-token`"

$ curl "https://app-usage.YOUR-SYSTEM-DOMAIN/organizations/`cf org YOUR-ORG --guid`/service_usages?start=YYYY-MM-DD&end=YYYY-MM-DD" -k -v -H "authorization: `cf oauth-token`"
```

- Usage Service Client Credentials
  - PAS -> Credentials -> UAA -> AUsage Service Client Credentials
```
./telemetry-collector collect --url https://pcf.pcf.syanagihara.cf --username admin --password admin --env-type development --cf-api-url https://api.sys.pcf.syanagihara.cf --usage-service-url https://app-usage.sys.pcf.syanagihara.cf --usage-service-client-id usage_service --usage-service-client-secret USAGE-SERVICE-CLIENT-SECRET --output-dir output --insecure-skip-tls-verify --usage-service-insecure-skip-tls-verify
```
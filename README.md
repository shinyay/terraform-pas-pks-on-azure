# Tarraform PAS and PKS for Azure

## terraform.tfvars
- subscription_id = az account list|jq '.[].id' 
- tenant_id       = az account list|jq '.[].tenantId'
- client_id       = az ad sp list --display-name "Service Principal for BOSH by syanagihara" | jq '.[].appId'

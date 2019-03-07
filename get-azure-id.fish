#!/usr/bin/env fish

echo "SUBSCRIPTION_ID"
cat terraform.tfstate | jq -r .modules[0].outputs.subscription_id.value
echo "TENANT_ID"
cat terraform.tfstate | jq -r .modules[0].outputs.tenant_id.value
echo "CLIENT_ID"
cat terraform.tfstate | jq -r .modules[0].outputs.client_id.value
echo "CLIENT_SECRET"
cat terraform.tfstate | jq -r .modules[0].outputs.client_secret.value

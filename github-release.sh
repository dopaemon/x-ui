#!/bin/bash

repo=dopaemon/x-ui

upload_url=$(curl -s -H "Authorization: token $TOKEN"  \
     -d '{"tag_name": "0.3.4", "name":"X-UI "$VERSIONS" Việt Hoá","body":"$INFORELEASE"}'  \
     "https://api.github.com/repos/$repo/releases" | jq -r '.upload_url')

upload_url="${upload_url%\{*}" > /dev/null 2>&1

curl -s -H "Authorization: token $TOKEN"  \
        -H "Content-Type: application/gzip" \
        --data-binary @/tmp/ci/amd64/x-ui-linux-amd64.tar.gz  \
        "$upload_url?name=x-ui-linux-amd64.tar.gz&label=x-ui-linux-amd64.tar.gz"

curl -s -H "Authorization: token $TOKEN"  \
        -H "Content-Type: application/gzip" \
        --data-binary @/tmp/ci/arm64/x-ui-linux-arm64.tar.gz  \
        "$upload_url?name=x-ui-linux-arm64.tar.gz&label=x-ui-linux-arm64.tar.gz"

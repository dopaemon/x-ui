#!/bin/bash

repo=dopaemon/x-ui

upload_url=$(curl -s -H "Authorization: token $token"  \
     -d '{"tag_name": "0.3.2", "name":"X-UI 0.3.2 Việt Hoá","body":"Việt Hoá X-UI Từ Bản Gốc"}'  \
     "https://api.github.com/repos/$repo/releases" | jq -r '.upload_url')

upload_url="${upload_url%\{*}"

echo "uploading asset to release to url : $upload_url"

curl -s -H "Authorization: token $token"  \
        -H "Content-Type: application/gzip" \
        --data-binary @/tmp/x-ui/x-ui-linux-amd64.tar.gz  \
        "$upload_url?name=x-ui-linux-amd64.tar.gz&label=x-ui-linux-amd64.tar.gz"

curl -s -H "Authorization: token $token"  \
        -H "Content-Type: application/gzip" \
        --data-binary @/tmp/x-ui/x-ui-linux-arm64.tar.gz  \
        "$upload_url?name=x-ui-linux-arm64.tar.gz&label=x-ui-linux-arm64.tar.gz"

#!/bin/bash

repo=dopaemon/x-ui

upload_url=$(curl -s -H "Authorization: token $token"  \
     -d '{"tag_name": "0.3.3", "name":"X-UI 0.3.3 Việt Hoá","body":"Việt Hoá X-UI Từ Bản Gốc\nCập Nhật Phiên bản Cho X86/Arm32-v7a Không chắc có hoạt động, Vui lòng tạo Issues nếu có bất kỳ lỗi nào"}'  \
     "https://api.github.com/repos/$repo/releases" | jq -r '.upload_url')

upload_url="${upload_url%\{*}"

echo "uploading asset to release to url : $upload_url"

echo "Uploading amd64 Compile OUTPUT"

curl -s -H "Authorization: token $token"  \
        -H "Content-Type: application/gzip" \
        --data-binary @/tmp/x-ui/src-zip/x-ui-linux-amd64.tar.gz  \
        "$upload_url?name=x-ui-linux-amd64.tar.gz&label=x-ui-linux-amd64.tar.gz"

echo "Uploading arm64 Compile OUTPUT"

curl -s -H "Authorization: token $token"  \
        -H "Content-Type: application/gzip" \
        --data-binary @/tmp/x-ui/src-zip/x-ui-linux-arm64.tar.gz  \
        "$upload_url?name=x-ui-linux-arm64.tar.gz&label=x-ui-linux-arm64.tar.gz"

echo "Uploading x86 Compile OUTPUT"

curl -s -H "Authorization: token $token"  \
        -H "Content-Type: application/gzip" \
        --data-binary @/tmp/x-ui/src-zip/x-ui-linux-x86.tar.gz  \
        "$upload_url?name=x-ui-linux-x86.tar.gz&label=x-ui-linux-x86.tar.gz"

echo "Uploading arm32 Compile OUTPUT"

curl -s -H "Authorization: token $token"  \
        -H "Content-Type: application/gzip" \
        --data-binary @/tmp/x-ui/src-zip/x-ui-linux-arm32.tar.gz  \
        "$upload_url?name=x-ui-linux-arm32.tar.gz&label=x-ui-linux-arm32.tar.gz"

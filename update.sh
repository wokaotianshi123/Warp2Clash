#!/bin/bash
export LANG=zh_CN.UTF-8
DOMAIN="cftokv.wofuck.rr.nu"
TOKEN="papa"
if [ -n "$1" ]; then 
  FILENAME="$1"
else
  echo "无文件名"
  exit 1
fi
BASE64_TEXT=$(head -n 20000 $FILENAME | base64)
curl -k "https://$DOMAIN/$FILENAME?token=$TOKEN&b64=$BASE64_TEXT"
echo "更新数据完成"

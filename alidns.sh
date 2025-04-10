#!/bin/bash
FLAG="(\.com\.cn|\.gov\.cn|\.net\.cn|\.org\.cn|\.ac\.cn|\.gd\.cn)$"


if ! command -v aliyun >/dev/null; then
	echo "错误: 你需要先安装 aliyun 命令行工具 https://help.aliyun.com/document_detail/121541.html。" 1>&2
	exit 1
fi

DOMAIN=$(expr match "$CERTBOT_DOMAIN" '.*\.\(.*\..*\)')
SUB_DOMAIN=$(expr match "$CERTBOT_DOMAIN" '\(.*\)\..*\..*')

if echo $CERTBOT_DOMAIN |grep -E -q "$FLAG"; then

  DOMAIN=`echo $CERTBOT_DOMAIN |grep -oP '(?<=)[^.]+('$FLAG')'`
  SUB_DOMAIN=`echo $CERTBOT_DOMAIN |grep -oP '.*(?=\.[^.]+('$FLAG'))'`

fi

if [ -z $DOMAIN ]; then
    DOMAIN=$CERTBOT_DOMAIN
fi
if [ ! -z $SUB_DOMAIN ]; then
    SUB_DOMAIN=.$SUB_DOMAIN
fi

# Get ESA site info and check if domain exists
SITE_ID=$(aliyun esa ListSites | grep -A 3 -B 3 "\"SiteName\": \"$DOMAIN\"" | grep '"SiteId": [0-9]*' | head -1 | sed 's/.*: //;s/,$//')

if [ ! -z "$SITE_ID" ]; then
	echo "Found site ID for $DOMAIN: $SITE_ID"
else
	echo "Error: Site ID for $DOMAIN not found. Please check if the domain is correct and exists in ESA."
	exit 1
fi

if [ $# -eq 0 ]; then
	echo "Adding DNS record for _acme-challenge$SUB_DOMAIN.$DOMAIN"
	aliyun esa CreateRecord \
		--SiteId $SITE_ID \
		--RecordName "_acme-challenge"$SUB_DOMAIN.$DOMAIN \
		--Type "TXT" \
		--Data "{\"Value\":\"$CERTBOT_VALIDATION\"}" \
		--Ttl 1
	/bin/sleep 20
else
	echo "Deleting DNS record for \"_acme-challenge\"$SUB_DOMAIN.$DOMAIN"
	RecordId=$(aliyun esa ListRecords \
		--SiteId $SITE_ID \
		--RecordName "_acme-challenge"$SUB_DOMAIN.$DOMAIN \
		--Type "TXT" \
		| grep "RecordId" \
		| grep -Eo "[0-9]+")

	echo "RecordId: $RecordId"
	if [ -z "$RecordId" ]; then
		echo "Error: Record ID for _acme-challenge$SUB_DOMAIN.$DOMAIN not found. Please check if the record exists."
		exit 1
	fi

	aliyun esa DeleteRecord \
		--RecordId $RecordId
fi

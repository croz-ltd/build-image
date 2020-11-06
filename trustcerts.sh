#!/usr/bin/env bash

DESTINATION=/usr/local/share/ca-certificates

function exportCerts() {
  destination=$2
  hostPort=$(echo "$1" | sed 's/https\?:\/\///')
  if [[ ! "$hostPort" =~ ":" ]]; then
    hostPort="$1:443"
  fi
  echo "Fetching $hostPort cert"
  (openssl s_client -showcerts -connect ${hostPort} & sleep 4) | \
    awk '/-----BEGIN CERTIFICATE-----/,/-----END CERTIFICATE-----/{if(/-----BEGIN CERTIFICATE-----/){a++}; out=destination"/"hostPort"."a".crt"; print > out}' \
    hostPort=$hostPort destination=$destination
}

if [ -f "trust-hostports.txt" ]; then
  while read hostPort; do
    exportCerts ${hostPort} ${DESTINATION}
  done < trust-hostports.txt
fi

update-ca-certificates

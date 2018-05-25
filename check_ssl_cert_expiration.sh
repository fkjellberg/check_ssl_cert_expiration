#!/bin/sh
# Copyright 2018 Fredrik Kjellberg
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

function check_ssl_cert_expiration {
    SSL_CERT_FINGERPRINT=$(echo | openssl s_client -servername $1 -connect $1:443 2>/dev/null | openssl x509 -fingerprint -sha1 -noout -in /dev/stdin)
    SSL_CERT_EXPIRATION_DATE=$(echo | openssl s_client -servername $1 -connect $1:443 2>/dev/null | openssl x509 -noout -dates | grep -E "^notAfter=" | cut -c10-)
    DAYS_UNTIL_EXPIRATION=$(expr '(' $(date -d "$SSL_CERT_EXPIRATION_DATE" +%s) - $(date +%s) ')' / 86400)
    if [ $DAYS_UNTIL_EXPIRATION -lt 0 ]; then
        echo $1 expired on $SSL_CERT_EXPIRATION_DATE
    else
        if [ -z "$days" ] || [ "$DAYS_UNTIL_EXPIRATION" -le "$days" ]; then
            printf "%-30s expires in %4s days on %-25s %s\n" $1 $DAYS_UNTIL_EXPIRATION "$SSL_CERT_EXPIRATION_DATE" "$SSL_CERT_FINGERPRINT"
        fi
    fi
}

function display_usage {
    echo "Usage: $(basename $0) -d <days> -f <file> [host1] [host2] ..."
}

args=$(getopt -o "d:f:h" -- "$@")
if [ $? != 0 ]; then
    display_usage
    exit 2
fi

eval set -- "$args"

while [ $# -ge 1 ]; do
    case "$1" in
        -d)
            days="$2"
            shift
            ;;
        -f)
            filename="$2"
            shift
            ;;
        -h)
            display_usage
            exit 0
            ;;
        --)
            shift
            break
            ;;
    esac

    shift
done

if [ ! -z "$filename" ]; then
    if [ "$filename" == "-" ]; then
        while read servername; do
            if [ ! -z "$servername" ] && [[ ! "$servername" =~ ^#.*$ ]]; then
                check_ssl_cert_expiration $servername
            fi
        done
    else
        while read servername; do
            if [ ! -z "$servername" ] && [[ ! "$servername" =~ ^#.*$ ]]; then
                check_ssl_cert_expiration $servername
            fi
        done < $filename
    fi
fi

for servername in "$@"; do
   check_ssl_cert_expiration $servername
done

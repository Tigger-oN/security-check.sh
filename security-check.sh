#!/bin/sh
#
# Present the last records in the FreeBSD Security Advisories and
# Errata notices RSS

VERSION="20241207"

# RSS location
URL="https://www.freebsd.org/security/feed.xml"

usage () {
    out="
Display the last 3 months of FreeBSD Security Advisories and Errata
notices published in the FreeBSD security feed.

The feed is located here:
 ${URL}

Script version: ${VERSION}

"
    printf "%s" "${out}"
    exit
}

if [ -n "${1}" ]
then
    usage
fi

printf "\nGetting the latest feed data...\n"
FEED=`fetch -qo - "${URL}"`

if [ ${?} -ne 0 -o -z "${FEED}" ]
then
    printf "\n\
Possible network issue (guess only) trying to download the latest\ 
FreeBSD Security Advisories and Errata notices RSS.\n\
\n\
Try again or check your network status\n\n"
    exit 1
fi

# Limit to last 3 months AND support both date formats.
# Why two different date formats are use?
D1=`date "+%b %y"`
D2=`date -v-1m "+%b %y"`
D3=`date -v-2m "+%b %y"`
D1a=`date "+%Y-%m"`
D2a=`date -v-1m "+%Y-%m"`
D3a=`date -v-2m "+%Y-%m"`

# There could be a way to combine the inital grep | sed call.
OUT=`printf "%s" "${FEED}" | grep -io "<title>.*<\/title>\|<link>.*<\/link>\|<pubDate>.*<\/pubDate>" | sed 's/\(<title>\)\(.*\)\(<\/title>\)/\n\2/; s/\(<link>\)\(.*\)\(<\/link>\)/\2/; s/\(<pubDate>\)\(.*\)\(<\/pubDate>\)/\2/' | grep -B2 "${D1}\|${D2}\|${D3}\|${D1a}\|${D2a}\|${D3a}" | sed 's/^--$//; s/ 00:00 UTC$//'`

if [ -z "${OUT}" ]
then
    printf "\nNo FreeBSD Security Advisories or Erratas for the last 3 months.\n\n"
else 
    printf "\nMost recent FreeBSD Security Advisories and Errata notices\n\n%s\n\n" "${OUT}"
fi


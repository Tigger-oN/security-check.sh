#!/bin/sh
#
# Present the last records in the FreeBSD Security Advisories and
# Errata notices RSS
#

VERSION="20250223"

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
# Why are two different date formats used?
D1=`date "+%b %y"`
D2=`date -v-1m "+%b %y"`
D3=`date -v-2m "+%b %y"`
D1a=`date "+%Y-%m"`
D2a=`date -v-1m "+%Y-%m"`
D3a=`date -v-2m "+%Y-%m"`

# Clean and sort the feed.
RAW=`printf "%s" "${FEED}" | grep -io "<item>\|<\/item>\|<title>.*<\/title>\|<link>.*<\/link>\|<pubDate>.*<\/pubDate>" | grep -A3 "<item>" | tr -d "\n" | sed 's/--<item>/\n/g; s/<item>//; s/ 00:00 UTC//g' | sort -r | grep "${D1}\|${D2}\|${D3}\|${D1a}\|${D2a}\|${D3a}"`

if [ -z "${RAW}" ]
then
	printf "\nNo FreeBSD Security Advisories or Erratas for the last 3 months.\n\n"
	exit
fi

# Need to format the feed lines
IFS="
"
headerShown=""
for l in ${RAW}
do
	t=${l##*<title>}
	t=${t%%</title>*}
	a=${l##*<link>}
	a=${a%%</link>*}
	d=${l##*<pubDate>}
	d=${d%%</pubDate>*}
	type=`printf "%s" "${t}" | grep -o "^FreeBSD-SA-[0-9]\{2\}:"`
	if [ -n "${type}" -a -z "${headerShown}" ]
	then
		printf "\nSecurity Advisories\n\n"
		headerShown="1"
	elif [ -z "${type}" -a "${headerShown}" != "2" ]
	then
		printf "\nErrata notices\n\n"
		headerShown="2"
	fi
	printf "%s - %s\n%s\n\n" "${d}" "${t}" "${a}"
done
exit


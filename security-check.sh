#!/bin/sh
#
# Present the last records in the FreeBSD Security Advisories and
# Errata notices RSS
#

# RSS location
URL="https://www.freebsd.org/security/feed.xml"
# Script version
VERSION="20250301"
# Used with date formating
DATE_TMP=""
# Check if an item is new or not
LAST_CHECK_FILE="${HOME}/.${0##*/}.last"
LAST_CHECK_DATE="0"
NEW_ITEM=""
# And just in case someone wants to use with Linux
OS=`uname`

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

# For some odd reason, the feed has more than one date format.
# `date` options we need are OS dependent.
dateFormat () {
	NEW_ITEM=""
	if [ -z "${1}" ]
	then
		DATE_TMP="${1}"
		return
	fi
	if [ "${OS}" = "FreeBSD" ]
	then
		# Which date format version are we correcting?
		numb_only=`printf "%s" "${1}" | grep -o "[0-9-]\{10\}"`
		if [ -n "${numb_only}" ]
		then
			# Input is like 2025-02-28
			DATE_TMP=`date -j -f "%Y-%m-%d" "${1}" "+%e %b, %Y" 2> /dev/null`
			tmp=`date -j -f "%Y-%m-%d %H:%M:%S" "${1} 00:00:00" "+%s" 2> /dev/null`
		else
			# Input is like 28 Feb 25
			DATE_TMP=`date -j -f "%d %b %y" "${1}" "+%e %b, %Y" 2> /dev/null`
			tmp=`date -j -f "%d %b %y %H:%M:%S" "${1} 00:00:00" "+%s" 2> /dev/null`
		fi
	elif [ "${OS}" = "Linux" ]
	then
		# Linux has `date -d` which handles both feed date formats
		DATE_TMP=`date -d "${1}" "+%e %b, %Y" 2> /dev/null`
		tmp=`date -d "${1} 00:00:00" "+%s" 2> /dev/null`
	else
		DATE_TMP="${1}"
		return
	fi
	if [ -n "${tmp}" -a ${LAST_CHECK_DATE} -lt "${tmp}" ]
	then
		NEW_ITEM="yes"
	fi
}

# The date of the last check
lastCheck () {
	if [ -f "${LAST_CHECK_FILE}" ]
	then
		LAST_CHECK_DATE=`date -r "${LAST_CHECK_FILE}" +%s`
	fi
	touch "${LAST_CHECK_FILE}"
}

getFeed () {
	printf "\nGetting the latest feed data...\n"
	if [ "${OS}" = "FreeBSD" ]
	then
		FEED=`fetch -qo - "${URL}"`
	else
		# Might be on Linux, need to check
		if [ -n "`command -v wget`" ]
		then
			FEED=`wget -qO - "${URL}"`
		elif [ -n "`command -v curl`" ]
		then
			FEED=`curl -so - "${URL}"`
		else
			printf "\nUnable to locate either wget or curl.\n\nAt least one of these is required to download the feed.\n\n"
			exit
		fi
	fi

	if [ ${?} -ne 0 -o -z "${FEED}" ]
	then
		out="
Possible network issue (guess only) trying to download the latest
FreeBSD Security Advisories and Errata notices RSS.

Try again or check your network status"
		printf "%s\n\n" "${out}"
		exit 1
	fi
}

checkFeed () {
	header=`printf "%s" "${FEED}" | grep -o "<rss version=\"2.0\""`
	footer=`printf "%s" "${FEED}" | grep -o "</rss>"`
	if [ "${header}" != "<rss version=\"2.0\"" -o "${footer}" != "</rss>" ]
	then
		printf "\nThe downloaded feed appears to be invalid. Recommend checking the network\nconnection. If everything appears to be correct, please try again.\n\nIf the problem continues, manually check the data at:\n\n %s\n\n" "${URL}"
		exit
	fi
}

limitTo3Months () {
	# Limit to last 3 months and support both date formats used in the feed.
	if [ "${OS}" = "FreeBSD" ]
	then
		# Possible Darwin would be the same (unconfirmed)
		D1=`date "+%b %y"`
		D2=`date -v-1m "+%b %y"`
		D3=`date -v-2m "+%b %y"`
		D1a=`date "+%Y-%m"`
		D2a=`date -v-1m "+%Y-%m"`
		D3a=`date -v-2m "+%Y-%m"`
	elif [ "${OS}" = "Linux" ]
	then
		D1=`date "+%b %y"`
		D2=`date -d "last month" "+%b %y"`
		D3=`date -d "2 months ago" "+%b %y"`
		D1a=`date "+%Y-%m"`
		D2a=`date -d "last month" "+%Y-%m"`
		D3a=`date -d "2 months ago" "+%Y-%m"`
	fi

	# Clean and sort the feed.
	RAW=`printf "%s" "${FEED}" | grep -io "<item>\|<\/item>\|<title>.*<\/title>\|<link>.*<\/link>\|<pubDate>.*<\/pubDate>" | grep -A3 "<item>" | tr -d "\n" | sed 's/--<item>/\n/g; s/<item>//; s/ 00:00 UTC//g' | sort -r | grep "${D1}\|${D2}\|${D3}\|${D1a}\|${D2a}\|${D3a}"`

	if [ -z "${RAW}" ]
	then
		printf "\nNo FreeBSD Security Advisories or Erratas for the last 3 months.\n\n"
		exit
	fi
}

if [ -n "${1}" ]
then
	usage
fi

# Get the raw feed
getFeed

# Make sure we the feed is valid
checkFeed

# Limit to 3 months
limitTo3Months

# Get the details of the last check
lastCheck

# Format the feed lines
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
	dateFormat "${d}"
	d="${DATE_TMP}"
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
	if [ -n "${NEW_ITEM}" ]
	then
		printf "%s\n" "--- New item ---"
	fi
	printf "%s - %s\n%s\n\n" "${d}" "${t}" "${a}"
done
exit


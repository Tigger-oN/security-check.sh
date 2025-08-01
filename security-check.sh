#!/bin/sh
#
# Present the most recent FreeBSD Security Advisories and Errata notices.
# Orginally used the RSS, but that was changed to something pointless in July,
# 2025.

# Script version
VERSION="20250801"
# URLs
URL_ADVISORY="https://www.freebsd.org/security/advisories/"
URL_ERRATA="https://www.freebsd.org/security/notices/"
# The URL data
RAW_ADVISORY=""
RAW_ERRATA=""
# Check if an item is new or not
LAST_CHECK_FILE="${HOME}/.${0##*/}.last"
LAST_CHECK_DATE="0"
# If an item is new, set to "yes"
ITEM_NEW=""
# And keep track of the most recent date, YYYYMMDD format
ITEM_RECENT_DATE=""
# Which app is used to download the data?
APP_WEB=""
# Used to pass data around
DATA=""
# Date values for limiting
Y0=`date "+%Y"`
Y1=""
Y2=""
M0=`date "+%m"`
M1=""
M2=""

usage () {
	out="
Display the last 3 months of FreeBSD Security Advisories and Errata
notices published by FreeBSD.

The Security Advisories and Errata Notices are located here:
 ${URL_ADVISORY}
 ${URL_ERRATA}

Script version: ${VERSION}

"
	printf "%s" "${out}"
	exit
}

checkWebApp () {
	printf "\nChecking for a download application.\n"
	if [ -n "`command -v fetch`" ]
	then
		APP_WEB="fetch -qo -"
	elif [ -n "`command -v wget`" ]
	then
		APP_WEB="wget -qO -"
	elif [ -n "`command -v curl`" ]
	then
		APP_WEB="curl -so -"
	else
		printf "\nUnable to locate either fetch, wget or curl.\n\nAt least one of these is required to download the raw data from the FreeBSD website.\n\n"
		exit
	fi
}

getURLData () {
	printf "\nGetting the latest data...\n"
	RAW_ADVISORY=`${APP_WEB} "${URL_ADVISORY}"`
	RAW_ERRATA=`${APP_WEB} "${URL_ERRATA}"`

	if [ ${?} -ne 0 -o -z "${RAW_ADVISORY}" ]
	then
		out="
Possible network issue (guess only) trying to download the latest
FreeBSD Security Advisories and Errata notices data.

Try again or check your network status."
		printf "%s\n\n" "${out}"
		exit 1
	fi
}

checkValidData () {
	header=`printf "%s" "${2}" | grep -o "<!DOCTYPE html>"`
	footer=`printf "%s" "${2}" | grep -o "</html>"`
	if [ "${header}" != "<!DOCTYPE html>" -o "${footer}" != "</html>" ]
	then
		printf "\nThe downloaded %s appear to be invalid. Recommend checking the network\nconnection. If everything appears to be correct, please try again.\n\nIf the problem continues, manually check the data at:\n\n %s\n\n" "${1}" "${3}"
		exit
	fi
}

limitTo3Months () {
	M0=${M0#0}
	M1=$((M0 - 1))
	M2=$((M0 - 2))
	Y1=${Y0}
	Y2=${Y0}
	if [ ${M1} -lt 1 ]
	then
		M1=$((M1 + 12))
		Y1=$((Y0 - 1))
	fi
	if [ ${M2} -lt 1 ]
	then
		M2=$((M2 + 12))
		Y2=$((Y0 - 1))
	fi
	if [ $M0 -lt 10 ]
	then
		M0="0${M0}"
	fi
	if [ $M1 -lt 10 ]
	then
		M1="0${M1}"
	fi
	if [ $M2 -lt 10 ]
	then
		M2="0${M2}"
	fi
}

extract3Months () {
	DATA=`printf "%s" "${1}" | grep -A3 "<td class=\"txtdate\">${Y0}-${M0}-[0-9]\{2\}</td>\|<td class=\"txtdate\">${Y1}-${M1}-[0-9]\{2\}</td>\|<td class=\"txtdate\">${Y2}-${M2}-[0-9]\{2\}</td>" | tr -d '\n' | sed 's/<td class="txtdate">/\n<td class="txtdate">/g'`
}

# The date of the last item seen.
checkLast () {
	if [ -f "${LAST_CHECK_FILE}" ]
	then
		LAST_CHECK_DATE=`date -r "${LAST_CHECK_FILE}" +%Y%m%d`
	fi
}

# And keep track for the date of the most recent item seen.
setLast () {
	if [ -n "${ITEM_RECENT_DATE}" ]
	then
		touch -t "${ITEM_RECENT_DATE}0000" "${LAST_CHECK_FILE}"
	fi
}

# Check if the item date is new.
# Known limitation: We are only checking the date, not the items. If a
# secondary release is done on the same day, after the script has been called,
# it is possible the "new item" tag will be missing for the second update.
# Possible fix: Always show "new item" if the day is the same?
checkNew () {
	chkDate=`printf "%s" "${1}" | sed 's/-//g'`
	if [ -n "${LAST_CHECK_DATE}" -a ${LAST_CHECK_DATE} -lt ${chkDate} ]
	then
		ITEM_NEW="yes"
	else
		ITEM_NEW=""
	fi
	if [ -z "${ITEM_RECENT_DATE}" ]
	then
		ITEM_RECENT_DATE="${chkDate}"
	elif [ ${chkDate} -gt ${ITEM_RECENT_DATE} ]
	then
		ITEM_RECENT_DATE="${chkDate}"
	fi
}

# Pass the "group" and raw data to be displayed.
displayData () {

	extract3Months "${2}"

	if [ -z "${DATA}" ]
	then
		printf "\nNo %s in the last 3 months.\n" "${1}"
		if [ "${1}" = "Errata Notices" ]
		then
			printf "\n"
		fi
		return
	fi

	IFS="
"
	printf "\n%s\n\n" "${1}"

	for l in ${DATA}
	do
		d=${l##*<td class=\"txtdate\">}
		d=${d%%</td>*}
		u=${l##*href=\"}
		t=${u##*\">}
		t=${t%%<*}
		u=${u%%\">*}
		checkNew "${d}"
		if [ "${ITEM_NEW}" = "yes" ]
		then
			printf "%s\n" "--- New item ---"
		fi
		printf "%s - %s\n%s\n\n" "${d}" "${t}" "${u}"
	done
}

# Any arg, show the usage
if [ -n "${1}" ]
then
	usage
fi

# Confirm there is an app that can download
checkWebApp

# get the URL contents
getURLData

# check for valid data
checkValidData "Security Advisories" "${RAW_ADVISORY}" "${URL_ADVISORY}"
checkValidData "Errata Notices" "${RAW_ERRATA}" "${URL_ERRATA}"

# limit to the most recent records
limitTo3Months

# Get the details of the last check
checkLast

# Show any items
displayData "Security Advisories" "${RAW_ADVISORY}"
displayData "Errata Notices" "${RAW_ERRATA}"

# Keep track of seen items
setLast 

# Done
exit


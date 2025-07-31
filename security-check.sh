#!/bin/sh
#
# Present the most recent FreeBSD Security Advisories and Errata notices.
# Orginally used the RSS, but that was changed to something pointless in July,
# 2025.

# Script version
VERSION="20250731"
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

getURLData () {
	printf "\nGetting the latest feed data...\n"
	# Check for a download app
	if [ -n "`command -v fetch`" ]
	then
		RAW_ADVISORY=`fetch -qo - "${URL_ADVISORY}"`
		RAW_ERRATA=`fetch -qo - "${URL_ERRATA}"`
	elif [ -n "`command -v wget`" ]
	then
		RAW_ADVISORY=`wget -qO - "${URL_ADVISORY}"`
		RAW_ERRATA=`wget -qO - "${URL_ERRATA}"`
	elif [ -n "`command -v curl`" ]
	then
		RAW_ADVISORY=`curl -so - "${URL_ADVISORY}"`
		RAW_ERRATA=`curl -so - "${URL_ERRATA}"`
	else
		printf "\nUnable to locate either fetch, wget or curl.\n\nAt least one of these is required to download the raw data from FreeBSD.\n\n"
		exit
	fi

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

checkValid () {
	header=`printf "%s" "${RAW_ADVISORY}" | grep -o "<!DOCTYPE html>"`
	footer=`printf "%s" "${RAW_ADVISORY}" | grep -o "</html>"`
	if [ "${header}" != "<!DOCTYPE html>" -o "${footer}" != "</html>" ]
	then
		printf "\nThe downloaded Security Advisories appear to be invalid. Recommend checking the network\nconnection. If everything appears to be correct, please try again.\n\nIf the problem continues, manually check the data at:\n\n %s\n\n" "${URL_ADVISORY}"
		exit
	fi
	header=`printf "%s" "${RAW_ERRATA}" | grep -o "<!DOCTYPE html>"`
	footer=`printf "%s" "${RAW_ERRATA}" | grep -o "</html>"`
	if [ "${header}" != "<!DOCTYPE html>" -o "${footer}" != "</html>" ]
	then
		printf "\nThe downloaded Errata Notices appear to be invalid. Recommend checking the network\nconnection. If everything appears to be correct, please try again.\n\nIf the problem continues, manually check the data at:\n\n %s\n\n" "${URL_ERRATA}"
		exit
	fi
}

limitTo3Months () {
	Y0=`date "+%Y"`
	M0=`date "+%m"`
	M0=${M0#0}
	if [ ${M0} -gt 2 ]
	then
		M1=$((M0 - 1))
		M2=$((M0 - 2))
		Y1=${Y0}
		Y2=${Y0}
	elif [ ${M0} -eq 2 ]
	then
		M1=1
		M2=12
		Y1=${Y0}
		Y2=$((Y0 - 1))
	elif [ ${M0} -eq 1 ]
	then
		M1=12
		M2=11
		Y1=$((Y0 - 1))
		Y2=${Y1}
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

	RAW_ADVISORY=`printf "%s" "${RAW_ADVISORY}" | grep -A3 "<td class=\"txtdate\">${Y0}-${M0}-[0-9]\{2\}</td>\|<td class=\"txtdate\">${Y1}-${M1}-[0-9]\{2\}</td>\|<td class=\"txtdate\">${Y2}-${M2}-[0-9]\{2\}</td>" | tr -d '\n' | sed 's/<td class="txtdate">/\n<td class="txtdate">/g'`
	RAW_ERRATA=`printf "%s" "${RAW_ERRATA}" | grep -A3 "<td class=\"txtdate\">${Y0}-${M0}-[0-9]\{2\}</td>\|<td class=\"txtdate\">${Y1}-${M1}-[0-9]\{2\}</td>\|<td class=\"txtdate\">${Y2}-${M2}-[0-9]\{2\}</td>" | tr -d '\n' | sed 's/<td class="txtdate">/\n<td class="txtdate">/g'`

	if [ -z "${RAW_ADVISORY}" -a -z "${RAW_ERRATA}" ]
	then
		printf "\nNo FreeBSD Security Advisories or Erratas Notices for the last 3 months.\n\n"
		exit
	fi

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
	touch -t "${ITEM_RECENT_DATE}0000" "${LAST_CHECK_FILE}"
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
	if [ -z "${2}" ]
	then
		printf "\nNo %s in the last 3 months.\n\n" "${1}"
		return
	fi

	IFS="
"
	printf "\n%s\n\n" "${1}"

	for l in ${2}
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
		#printf "date : %s\ntitle: %s\nURL  : %s\n" "${d}" "${t}" "${u}"
	done
}

# Any arg, show the usage
if [ -n "${1}" ]
then
	usage
fi

# otherwise, get the URL contents
getURLData

# check for valid data
checkValid

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


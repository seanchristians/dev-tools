#!/usr/bin/env bash

ACTIVE_USER=$(/usr/bin/id -unr)
ACTIVE_USER_ID=$(/usr/bin/id -ur)
HOME_DIR=$(/usr/bin/dscl -plist . read "/Users/${ACTIVE_USER}" NFSHomeDirectory | /usr/bin/plutil -extract 'dsAttrTypeStandard:NFSHomeDirectory.0' raw -)
DOWNLOADS_DIR=$(/bin/realpath "${HOME_DIR}/Downloads")

trash() {
	# From https://github.com/morgant/tools-osx
	# Modified by seanchristians to suit this script
	FINDER_PID=$(/bin/ps -u "${ACTIVE_USER}" | /usr/bin/grep CoreServices/Finder.app | /usr/bin/grep -v grep | /usr/bin/awk '{print $1}')

	# determine whether we have full disk access
	function have_full_disk_access() {
		if [ $(/usr/bin/sw_vers -productVersion | /usr/bin/cut -d . -f 1) -lt 11 ] && [ $(/usr/bin/sw_vers -productVersion | /usr/bin/cut -d . -f 2) -lt 15 ]; then
			true
		else
			/usr/bin/sqlite3 /Library/Application\ Support/com.apple.TCC/TCC.db 'select * from access' >/dev/null 2>&1 && true || false
		fi
	}

	# determine whether we can script the Finder or not
	function have_scriptable_finder() {
		# We must have a valid PID for Finder, plus we cannot be in `screen` (another thing that's broken)
		if [[ ($FINDER_PID -gt 1) && ("$STY" == "") ]]; then
			true
		else
			false
		fi
	}

	if ! have_full_disk_access; then
		printf "%s requires Full Disk Access!\n\n" "$(/usr/bin/basename "$0")"
		printf "Please go to System Preferences > Security & Privacy > Privacy > Full Disk Access,\n"
		printf "press the '+' button, and add:\n\n"
		printf "1. Your terminal application (usually /Applications/Utilities/Terminal.app)\n"
		printf "2. /usr/libexec/sshd-keygen-wrapper (if you plan to connect via SSH)\n"
		exit 1
	fi

	while [ $# -gt 0 ]; do
		# does the file we're trashing exist?
		if [ ! -e "$1" ]; then
			printf "trash: '%s': No such file or directory\n" "$1"
		else
			# determine if we'll tell Finder to trash the file via AppleScript (very easy, plus free undo
			# support, but Finder must be running for the user and is DOES NOT work from within `screen`)
			if have_scriptable_finder; then
				# determine whether we have an absolute path name to the file or not
				if [ "${1:0:1}" = "/" ]; then
					file="$1"
				else
					# expand relative to absolute path
					printf "Determining absolute path for '%s'... " "$1"
					file="$(/bin/realpath "$1")"
					if [ $? -eq 0 ]; then
						printf "Done.\n"
					else
						printf "ERROR!\n"
					fi
				fi
				printf "Telling Finder to trash '%s'... " "$file"
				if /usr/bin/osascript -e "tell application \"Finder\" to delete POSIX file \"$file\"" >/dev/null; then
					printf "Done.\n"
				else
					printf "ERROR!\n"
				fi
			# Finder isn't available for this user, so don't rely on it (we'll do all the dirty work ourselves)
			else
				# determine whether we should be putting this in a volume-specific .Trashes or user's .Trash
				IFS=/ read -r -d '' _ _ vol _ <<<"$1"
				if [[ ("${1:0:9}" == "/Volumes/") && (-n "$vol") && ($(readlink "/Volumes/$vol") != "/") ]]; then
					trash="/Volumes/${vol}/.Trashes/${ACTIVE_USER_ID}/"
				else
					trash="/Users/${ACTIVE_USER}/.Trash/"
				fi
				# create the trash folder if necessary
				if [ ! -d "$trash" ]; then
					/bin/mkdir -v "$trash"
				fi
				# move the file to the trash
				if [ ! -e "${trash}$1" ]; then
					/bin/mv -v "$1" "$trash"
				else
					# determine if the filename has an extension
					ext=false
					case "$1" in
					*.*) ext=true ;;
					esac

					# keep incrementing a number to append to the filename to mimic Finder
					i=1
					if $ext; then
						new="${trash}${1%%.*} ${i}.${1##*.}"
					else
						new="${trash}$1 $i"
					fi
					while [ -e "$new" ]; do
						((i = $i + 1))
						if $ext; then
							new="${trash}${1%%.*} ${i}.${1##*.}"
						else
							new="${trash}$1 $i"
						fi
					done

					#move the file to the trash with the new name
					/bin/mv -v "$1" "$new"
				fi
			fi
		fi
		shift
	done
}

DOWNLOADS=$(/usr/bin/stat -f '%B %R' "${DOWNLOADS_DIR}/"* | /usr/bin/awk -v threshold="$(/bin/date -jv -1d +%s)" '$1 < threshold {$1="";print}' | /usr/bin/awk '{$1=$1;print}')

IFS=$'\n'
for FILE in ${DOWNLOADS}; do
	trash "${FILE}"
done

unset IFS
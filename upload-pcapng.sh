#!/bin/bash
VERSION="v1.3"
SCRIPTPATH="$( cd "$(dirname "$0")" || { echo -e "\e[91mERROR\e[0m: Script path cannot be found" ; exit 1; } >/dev/null 2>&1 ; pwd -P )"
GUI=false
USER_AGENT="upload-pcapng $VERSION, part of wpa-sec-api by Czechball (https://github.com/Czechball/wpa-sec-api)"
CONFIGFILE="$SCRIPTPATH"/config.txt

if test -f "$CONFIGFILE"; then
	:
else
	echo "$CONFIGFILE doesn't exist, creating a new one using setup.sh"
	"$SCRIPTPATH"/setup.sh
fi

source "$CONFIGFILE" || { echo -e "\e[91mERROR\e[0m: $CONFIGFILE doesn't exist in script path" ; exit 1; }

echo "wpa-sec-api $VERSION by Czechball"

show_usage ()
{
	echo "Invalid arguments. Usage: $0 <file> <options> Use $0 -h for help"
	exit 1
}

while getopts "d:hg?:*:" arg; do
	case ${arg} in
	d ) DIRECTORY="$OPTARG";;
	h )
		echo "upload-pcapng by Czechball, part of wpa-sec-api scripts"
		echo "wpa-sec-api version $VERSION"
		echo "https://github.com/Czechball/wpa-sec-api"
		echo
		printf "Usage:\n\
	%s <file.pcapng> or %s -d <direcory> or %s -g <other options>
Options:\n\
	-d		direcory with captures (will upload all network capture files and move them to a subdirectory named uploaded)\n\
	-g		run in GUI using Zenity" "$0" "$0" "$0"
		echo
		exit
	;;
	g )
		if which zenity >/dev/null; then
			echo -e "Running in GUI mode..."
			GUI=true
		else
			echo -e "\e[91mERROR\e[0m: Zenity not found."
		fi
	;;
	\? ) show_usage
	;;
	* )  show_usage
	;;
  esac
done
shift $(( OPTIND-1 ))

error ()
{
	if [[ "$2" == true ]]; then
		zenity --error --ellipsize --text="$1"
		exit 1
	fi
	echo -e "\e[91mERROR\e[0m: $1"
	exit 1
}

warning ()
{
	echo -e "\e[33mWarning\e[0m: $1"
}

info ()
{
	if [[ "$2" == true ]]; then
		zenity --info --ellipsize --text="$1"
	else
		echo -e "\e[92m$1\e[0m"
	fi
}

if curl --head -s "$DWPAURL" >/dev/null; then
	:
else
	error "$DWPAURL couldn't be reached, check your internet connection" $GUI
fi

if [[ $DWPAKEY == "" ]]; then
	error "No wpa-sec key supplied. Enter your key into $CONFIGFILE" $GUI
fi

if [[ $DIRECTORY == "" ]]; then
	FILES_R=$*
	FILES_N=${FILES_R// /$'\n'}
	mapfile -t FILES < <(echo $FILES_N)
	if [[ $FILES == "" ]]; then
		error "No file specified. Use $0 -h for help" $GUI
	fi
	FILE_COUNT="${#FILES[@]}"
	C=0
	TOTAL_DIR_COUNT=0
			if test -f $FILE; then
				if [[ $GUI = true ]]; then
					for FILE in $FILES; do
						HS_COUNT=""
						PM_COUNT=""
						C=$(( C + 1 ))
						RESULT=$(curl -s "$DWPAURL/?submit" -X POST -F "file=@$FILE" -b "key=$DWPAKEY" -A "$USER_AGENT" 2>/dev/null)
						HS_COUNT=$(echo "$RESULT" | grep "EAPOL pairs (best)" | sed 's/[^0-9]*//g')
						PM_COUNT=$(echo "$RESULT" | grep "PMKID (best)" | sed 's/[^0-9]*//g')
						TOTAL_COUNT=$(( HS_COUNT + PM_COUNT ))
						TOTAL_DIR_COUNT=$(( TOTAL_DIR_COUNT + TOTAL_COUNT ))
						printf %.3f\\n "$((1000 *   100*C/FILE_COUNT  ))e-3"
						echo "# File: $C/$FILE_COUNT	Handshakes: $TOTAL_DIR_COUNT"
					done > >(zenity --progress --width="500" --auto-close --auto-kill --time-remaining --title="Uploading $FILE_COUNT files")
					# if echo "$RESULT" | grep "No valid handshakes" > /dev/null; then
					# 	error "No valid handshakes/PMKIDs found." $GUI
					# elif echo "$RESULT" | grep "Not a valid capture file" > /dev/null; then
					# 	error "Not a valid capture file." $GUI
					# elif echo "$RESULT" | grep "was already submitted" > /dev/null; then
					# 	error "File was already uploaded before." $GUI
					# fi
					zenity --info --title="Success" --text="$TOTAL_COUNT handshakes uploaded from $FILE_COUNT file(s)" --ellipsize
					exit
				else
					for FILE in $FILES; do
						printf "Uploading %s... " "$FILE"
						RESULT=$(curl -s "$DWPAURL/?submit" -X POST -F "file=@$FILE" -b "key=$DWPAKEY" -A "$USER_AGENT" 2>/dev/null)
						if echo "$RESULT" | grep "No valid handshakes" > /dev/null; then
							echo -e "\e[91mno valid handshakes/PMKIDs found.\e[0m"
						elif echo "$RESULT" | grep "Not a valid capture file" > /dev/null; then
							echo -e "\e[91mnot a valid capture file.\e[0m"
						elif echo "$RESULT" | grep "was already submitted" > /dev/null; then
							echo -e "\e[91mfile was already uploaded before.\e[0m"
						fi
						HS_COUNT=$(echo "$RESULT" | grep "EAPOL pairs (best)" | sed 's/[^0-9]*//g')
						PM_COUNT=$(echo "$RESULT" | grep "PMKID (best)" | sed 's/[^0-9]*//g')
						TOTAL_COUNT=$(( HS_COUNT + PM_COUNT ))
						TOTAL_DIR_COUNT=$(( TOTAL_DIR_COUNT + TOTAL_COUNT ))
						if [[ $TOTAL_COUNT != 0 ]]; then
							echo -e "\e[92m$TOTAL_COUNT handshakes\e[0m"
						fi
					done
					info "Total handshakes: $TOTAL_DIR_COUNT"
					exit
				fi
			else
				warning "$FILES is not a valid file."
			fi
else
	if test -d "$DIRECTORY"; then
		mapfile -t FILES < <(find "$DIRECTORY"/ -maxdepth 1 -print -exec file {} \; | grep "pcapng capture file" | awk '{print substr($1,1,length($1)-1)}')
		if [[ $FILES == "" ]]; then
			error "No valid capture files found in $DIRECTORY" $GUI
		fi
		mkdir -p "$DIRECTORY"/uploaded || { error "Cannot create uploaded directory" $GUI; }
		echo "Uploading all capture files from $DIRECTORY and moving to $DIRECTORY/uploaded"
		TOTAL_DIR_COUNT=0
		C=0
		FILE_COUNT="${#FILES[@]}"
		if [[ $GUI == true ]]; then
				for FILE in "${FILES[@]}" ; do
					HS_COUNT=""
					PM_COUNT=""
					C=$(( C + 1 ))
					RESULT=$(curl -s "$DWPAURL/?submit" -X POST -F "file=@$FILE" -b "key=$DWPAKEY" -A "$USER_AGENT" 2>/dev/null)
					HS_COUNT=$(echo "$RESULT" | grep "EAPOL pairs (best)" | sed 's/[^0-9]*//g')
					PM_COUNT=$(echo "$RESULT" | grep "PMKID (best)" | sed 's/[^0-9]*//g')
					TOTAL_COUNT=$(( HS_COUNT + PM_COUNT ))
					TOTAL_DIR_COUNT=$(( TOTAL_DIR_COUNT + TOTAL_COUNT ))
					echo "# File: $C/$FILE_COUNT	Handshakes: $TOTAL_DIR_COUNT"
					printf %.3f\\n "$((1000 *   100*C/FILE_COUNT  ))e-3"
					mv "$FILE" "$DIRECTORY"/uploaded || { error "Cannot move $FILE to uploaded" $GUI; }
				done > >(zenity --progress --width="500" --auto-close --auto-kill --time-remaining --title="Uploading $DIRECTORY")
			zenity --info --ellipsize --title="Success" --text="Uploaded $FILE_COUNT files containing $TOTAL_DIR_COUNT handshakes"
		else
			for FILE in "${FILES[@]}" ; do
				HS_COUNT=""
				PM_COUNT=""
				C=$(( C + 1 ))
				printf "Uploading %s... [%s/%s]: " "$FILE" "$C" "${#FILES[@]}"
				RESULT=$(curl -s "$DWPAURL/?submit" -X POST -F "file=@$FILE" -b "key=$DWPAKEY" -A "$USER_AGENT" 2>/dev/null)
				if echo "$RESULT" | grep "No valid handshakes" > /dev/null; then
					echo -e "\e[91mno valid handshakes/PMKIDs found.\e[0m"
				elif echo "$RESULT" | grep "Not a valid capture file" > /dev/null; then
					echo -e "\e[91mnot a valid capture file.\e[0m"
				else
				HS_COUNT=$(echo "$RESULT" | grep "EAPOL pairs (best)" | sed 's/[^0-9]*//g')
				PM_COUNT=$(echo "$RESULT" | grep "PMKID (best)" | sed 's/[^0-9]*//g')
				TOTAL_COUNT=$(( HS_COUNT + PM_COUNT ))
				TOTAL_DIR_COUNT=$(( TOTAL_DIR_COUNT + TOTAL_COUNT ))
				echo -e "\e[92m$TOTAL_COUNT handshakes\e[0m"
				fi
				mv "$FILE" "$DIRECTORY"/uploaded || { error "Cannot move $FILE to uploaded" $GUI; }
			done
			echo -e "\e[92mUploaded $TOTAL_DIR_COUNT handshakes in total from $C files.\e[0m"
		fi
	else
		error "$DIRECTORY is not a valid directory. Aborting" $GUI
	fi
fi

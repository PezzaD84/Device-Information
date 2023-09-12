#!/bin/bash
#
# Author  : Perry Driscoll - https://github.com/PezzaD84
# Created : 23/10/2020
# Updated : 12/9/2023
# Version : v3
#
#########################################################################################
# Description:
#		Script to gather device information and display it to the end user.
#
#########################################################################################
# Copyright © 2023 Perry Driscoll <https://github.com/PezzaD84>
#
# This file is free software and is shared "as is" without any warranty of 
# any kind. The author gives unlimited permission to copy and/or distribute 
# it, with or without modifications, as long as this notice is preserved. 
# All usage is at your own risk and in no event shall the authors or 
# copyright holders be liable for any claim, damages or other liability.
#########################################################################################

##############################################################
# Functions
##############################################################

DialogInstall(){
		pkgfile="SwiftDialog.pkg"
		logfile="/Library/Logs/SwiftDialogInstallScript.log"
		URL="https://github.com$(curl -sfL "$(curl -sfL "https://github.com/bartreardon/swiftDialog/releases/latest" | tr '"' "\n" | grep -i "expanded_assets" | head -1)" | tr '"' "\n" | grep -i "^/.*\/releases\/download\/.*\.pkg" | head -1)"
		
		# Start Log entries
		echo "--" >> ${logfile}
		echo "`date`: Downloading latest version." >> ${logfile}
		
		# Download installer
		curl -s -L -J -o /tmp/${pkgfile} ${URL}
		echo "`date`: Installing..." >> ${logfile}
		
		# Change to installer directory
		cd /tmp
		
		# Install application
		sudo installer -pkg ${pkgfile} -target /
		sleep 5
		echo "`date`: Deleting package installer." >> ${logfile}
		
		# Remove downloaded installer
		rm /tmp/"${pkgfile}"
}

##############################################################
# Check if SwiftDialog is installed (SwiftDialog created by Bart Reardon https://github.com/bartreardon/swiftDialog)
##############################################################

if ! command -v dialog &> /dev/null
then
	echo "SwiftDialog is not installed. App will be installed now....."
	sleep 2
	
	DialogInstall
	
else
	echo "SwiftDialog is installed. Checking installed version....."
	
	installedVersion=$(dialog -v | sed 's/./ /6' | awk '{print $1}')
	
	latestVersion=$(curl -sfL "https://github.com/bartreardon/swiftDialog/releases/latest" | tr '"' "\n" | grep -i "expanded_assets" | head -1 | tr '/' ' ' | awk '{print $7}' | tr -d 'v')
	
	if [[ $installedVersion != $latestVersion ]]; then
		echo "Dialog needs updating"
		DialogInstall
	else
		echo "Dialog is up to date. Continuing to assemble...."
	fi
	sleep 3
fi

#########################################################################################
# Information Variables
#########################################################################################

serial=$(system_profiler SPHardwareDataType | awk '/Serial Number/{print $4}')

model=$(ioreg -l | awk '/product-name/ { split($0, line, "\""); printf("%s\n", line[4]); }')

localname=$(scutil --get LocalHostName)

sharename=$(scutil --get HostName)

username=$(ls -l /dev/console | awk '{ print $3 }')

networkname=$(/System/Library/PrivateFrameworks/Apple80211.framework/Resources/airport -I | awk -F: '/ SSID/{print $2}')

ipadd=$(while read -r line; do
	sname=$(echo "$line" | awk -F  "(, )|(: )|[)]" '{print $2}')
	sdev=$(echo "$line" | awk -F  "(, )|(: )|[)]" '{print $4}')
	#echo "Current service: $sname, $sdev, $currentservice"
	if [ -n "$sdev" ]; then
		ifout="$(ifconfig "$sdev" 2>/dev/null)"
		echo "$ifout" | grep 'status: active' > /dev/null 2>&1
		rc="$?"
		if [ "$rc" -eq 0 ]; then
			currentservice="$sname"
			currentip=$(echo "$ifout" | awk '/inet /{print $2}')

			# may have multiple active devices, so echo it here
			echo "$currentip"
		fi
	fi
done <<< "$(networksetup -listnetworkserviceorder | grep 'Hardware Port')")

networkhardware=$(while read -r line; do
	sname=$(echo "$line" | awk -F  "(, )|(: )|[)]" '{print $2}')
	sdev=$(echo "$line" | awk -F  "(, )|(: )|[)]" '{print $4}')
	#echo "Current service: $sname, $sdev, $currentservice"
	if [ -n "$sdev" ]; then
		ifout="$(ifconfig "$sdev" 2>/dev/null)"
		echo "$ifout" | grep 'status: active' > /dev/null 2>&1
		rc="$?"
		if [ "$rc" -eq 0 ]; then
			currentservice="$sname"
			currentip=$(echo "$ifout" | awk '/inet /{print $2}')

			# may have multiple active devices, so echo it here
			echo "$currentservice"
		fi
	fi
done <<< "$(networksetup -listnetworkserviceorder | grep 'Hardware Port')")

jamfcheck=$(
if [[ -f /usr/local/jamf/bin/jamf ]]
then
	echo "JAMF Installed and Running"
	else
	echo "JAMF Not installed"
fi
)

mdmprofile=$(mdm=$(sudo profiles list | grep 'com.jamfsoftware.tcc.management' | awk '{print $4}' | sed -e 's#com.##' -e 's#.tcc.management##')

if [[ $mdm == jamfsoftware ]]
then
	echo "JAMF MDM Installed"
	else
	echo "No MDM profile found"
fi)

FVSTATUS=$(FV=$(sudo fdesetup list | grep $username)

if [[ $FV == "" ]]; then
	echo "FileVault not enabled"
	if fdesetup status | grep On ; then
		echo "FV Enabled but not for current User"
	fi
else
	echo "FV Enabled"
fi)

OS=$(sw_vers --productVersion)

OSNAME=$(curl -s "https://support.apple.com/en-us/HT201260" | grep -A 22 "Latest version" | grep -m1 -B 2 $(sw_vers --productVersion | awk -F '.' '{print $1}') | grep macOS | sed -e 's#</tr><tr><td>##' -e 's#<br>##')

free_disk_space=$(osascript -l 'JavaScript' -e "ObjC.import('Foundation'); var freeSpaceBytesRef=Ref(); $.NSURL.fileURLWithPath('/').getResourceValueForKeyError(freeSpaceBytesRef, 'NSURLVolumeAvailableCapacityForImportantUsageKey', null); Math.round(ObjC.unwrap(freeSpaceBytesRef[0]) / 1000000000)")

TOTALDISKSPACE=$(diskutil info /dev/disk1 | grep "Disk Size" | awk -F ':' '{print $2}' | awk -F '.' '{print $1}')
			
percent=$((100*$free_disk_space/$TOTALDISKSPACE))

FREESPACE=$(echo ""$free_disk_space"GB "$percent"% Free")

CHIP=$(system_profiler SPHardwareDataType | grep Chip | awk -F ':' '{print $2}' | xargs)

RAM=$(system_profiler SPHardwareDataType | grep Memory | awk -F ':' '{print $2}' | xargs)

BANNER="/System/Library/Desktop Pictures/$(echo $OSNAME | awk -F 'macOS ' '{print $2}') Graphic.heic"

#########################################################################################
# Information List
#########################################################################################

cat << EOF > /tmp/dialogjson.json
{
	"listitem" : [
		{"title" : "Device Name:", "icon" : "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/HomeFolderIcon.icns", "statustext" : "$localname"},
		{"title" : "User Logged in:", "icon" : "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/UserIcon.icns", "statustext" : "$username"},
		{"title" : "Current Network:", "icon" : "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/GenericNetworkIcon.icns", "statustext" : "$networkname"},
		{"title" : "ActiveConnection:", "icon" : "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/AirDrop.icns", "statustext" : "$networkhardware"},
		{"title" : "Current IP:", "icon" : "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/ExecutableBinaryIcon.icns", "statustext" : "$ipadd"},
		{"title" : "FV Status:", "icon" : "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/FileVaultIcon.icns", "statustext" : "$FVSTATUS"},
		{"title" : "Free Disk Space:", "icon" : "https://ics.services.jamfcloud.com/icon/hash_522d1d726357cda2b122810601899663e468a065db3d66046778ceecb6e81c2b", "statustext" : "$FREESPACE"},
		{"title" : "MDM Status:", "icon" : "https://resources.jamf.com/images/logos/Jamf-Icon-color.png", "statustext" : "$mdmprofile"}
	]
}
EOF

#########################################################################################
# Set device model and Icon
#########################################################################################

model=$(ioreg -l | awk '/product-name/ { split($0, line, "\""); printf("%s\n", line[4]); }')

if [[ "$model" = *"Book"* ]]; then
	DeviceIcon="/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/com.apple.macbookpro-14-2021-silver.icns"
elif [[ "$model" = *"mini"* ]]; then
	DeviceIcon="/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/com.apple.macmini-2020.icns"
elif [[ "$model" = *"iMac"* ]]; then
	DeviceIcon="/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/com.apple.imac-unibody-27.icns"
fi

#########################################################################################
# Display information to User
#########################################################################################

dialog \
--title none \
--bannerimage "$BANNER" \
--bannertitle "Device Information" \
--titlefont 'shadow=1' \
--message none \
--icon "$DeviceIcon" \
--jsonfile /tmp/dialogjson.json \
--messagefont 'name=Arial,size=14' \
--height 590 \
--width 700 \
--infobox "Model:<br>**$model**\n\nSerial Number:<br>**$serial**\n\nOS Version:<br>**$OSNAME $OS**\n\nProcessor:<br>**$CHIP**\n\nMemory:<br>**$RAM**"

#!/bin/bash

#Set the correct location for swiftDialog and jq
#get them at https://github.com/bartreardon/swiftDialog and https://stedolan.github.io/jq/
dialog='/usr/local/bin/dialog'
jq='/usr/local/bin/jq'
source ./getCredsSwift.sh
getCreds

#this loop takes you to the window where you enter the device tag
while (true); do
  outputMessage=""

  #pop up our interface
  input=$($dialog -d -o -p -h --title "Asset Tag" --message "Please enter the asset tag or serial number" --textfield "Asset Tag",required --json -2)
  #exit if cancel button
  [ "$?" -eq 2 ] && exit 1
  assettag=$(echo $input | $jq --raw-output '."Asset Tag"')

  #lookup the device id from the given asset tag number
  myOutput=$(curl -H "Accept: application/json" -s -H "Authorization: Bearer $token" -X GET ${jssAddress}/JSSResource/mobiledevices/match/"$assettag")
  myID=$(echo "$myOutput" | $jq '.mobile_devices[].id')
  myName=$(echo "$myOutput" | $jq --raw-output '.mobile_devices[].name')
  myUserName=$(echo "$myOutput" | $jq --raw-output '.mobile_devices[].realname')

  #if we can't find the ID try again
  if [ -z "$myName" ]; then
    $dialog -d -o -p -h --title "Oops" --message "Bummer. The asset number $assettag was not found." --icon warning
    break
  fi

  while true; do

    input=$($dialog -d -o --json -2 --infobuttontext "Change iPad" --quitoninfo -p -h --title "Make a selection" --selecttitle "Action" --selectvalues "Update Inventory and Blank Push,\
Add to a Group,Remove from a Group,Clear Passcode,Send a Lock Message,Enable Lost Mode,Disable Lost Mode,List Group Membership,List Configuration Profiles,\
List Installed Apps,Wipe Device,Assign username,Rename iPad,Rename iPad to assigned username,Remove from all groups,\
Update Asset Number,Shutdown Device,Restart Device,Open JAMF page" --message "${outputMessage}")
    button_pressed=$?
    [ "$button_pressed" -eq 2 ] && exit 1
    [ "$button_pressed" -eq 3 ] && break

    actionentered=$(echo $input | $jq --raw-output '.SelectedOption')
    checkExpiration
    #let's see what was selected
    if [ "$actionentered" == "Update Inventory and Blank Push" ]; then
      #Run update inventory and blank push
      output=$(curl -k -H "Authorization: Bearer $token" ${jssAddress}/JSSResource/mobiledevicecommands/command/UpdateInventory/id/"$myID" -X POST -d "")
      output2=$(curl -k -H "Authorization: Bearer $token" ${jssAddress}/JSSResource/mobiledevicecommands/command/BlankPush/id/"$myID" -X POST -d "")
      #if we can't find the ID try again
      if echo "$output2" | grep -q "Not Found"; then
        outputMessage="Sorry, device was not found"
      else
        outputMessage="Update Inventory and Blank Push sent to $myName"
      fi

    fi

    if [ "$actionentered" == "Enable Lost Mode" ]; then
      input=$($dialog -d -o -h -p --json --title "Enable lost mode" --message "Set lost mode options" --textfield "Message to be sent",required --textfield "Phone Number" --checkbox "Play sound?")
      lostMessage=$(echo $input | $jq --raw-output '."Message to be sent"')
      lostPhone=$(echo $input | $jq --raw-output '."Phone Number"')
      lostSound=$(echo $input | $jq --raw-output '."Play sound?"')
      apiData="<mobile_device_command><general><command>EnableLostMode</command><lost_mode_message>${lostMessage}</lost_mode_message><lost_mode_phone>${lostPhone}</lost_mode_phone><lost_mode_with_sound>${lostSound}</lost_mode_with_sound></general><mobile_devices><mobile_device><id>${myID}</id></mobile_device></mobile_devices></mobile_device_command>"
      output=$(curl -H "Content-Type: text/xml" -k -H "Authorization: Bearer $token" ${jssAddress}/JSSResource/mobiledevicecommands/command/EnableLostMode/id/"$myID" -X POST -d "<?xml version=\"1.0\" encoding=\"ISO-8859-1\"?>$apiData")
      outputMessage="Lost mode command sent"
    fi

    if [ "$actionentered" == "Assign username" ]; then
      input=$($dialog -d -o -p -h --json --title "Assign a username" --textfield "Username" --message "Enter the username to assign")
      newUsername=$(echo $input | $jq --raw-output '.Username')
      apiData="<mobile_device><location><username>$newUsername</username></location></mobile_device>"
      curl -sS -k -i -H "Authorization: Bearer $token" -X PUT -H "Content-Type: text/xml" -d "<?xml version=\"1.0\" encoding=\"ISO-8859-1\"?>$apiData" ${jssAddress}/JSSResource/mobiledevices/id/"$myID"
      outputMessage="iPad assigned to $newUsername"
    fi


    if [ "$actionentered" == "Disable Lost Mode" ]; then
      apiData="<mobile_device_command><general><command>DisableLostMode</command></general><mobile_devices><mobile_device><id>${myID}</id></mobile_device></mobile_devices></mobile_device_command>"
      output=$(curl -H "Content-Type: text/xml" -k -H "Authorization: Bearer $token" ${jssAddress}/JSSResource/mobiledevicecommands/command/DisableLostMode/id/"$myID" -X POST -d "<?xml version=\"1.0\" encoding=\"ISO-8859-1\"?>$apiData")
      outputMessage="Lost mode disabled"
    fi

    if [ "$actionentered" == "Shutdown Device" ]; then
      #Shutdown the device
      output=$(curl -k -H "Authorization: Bearer $token" ${jssAddress}/JSSResource/mobiledevicecommands/command/ShutDownDevice/id/"$myID" -X POST -d "")
      if echo "$output" | grep -q "Not Found"; then
        outputMessage="The asset number $textentered was not found"
      else
        outputMessage="$myName was sent the Shutdown command"
      fi
    fi
    if [ "$actionentered" == "Restart Device" ]; then
      #Restart the device
      output=$(curl -k -H "Authorization: Bearer $token" ${jssAddress}/JSSResource/mobiledevicecommands/command/RestartDevice/id/"$myID" -X POST -d "")
      if echo "$output" | grep -q "Not Found"; then
        outputMessage="The asset number $textentered was not found"
      else
        outputMessage="$myName was sent the Restart command"
      fi
    fi

    if [ "$actionentered" == "Clear Passcode" ]; then
      #Clear the passcode
      output=$(curl -k -H "Authorization: Bearer $token" ${jssAddress}/JSSResource/mobiledevicecommands/command/ClearPasscode/id/"$myID" -X POST -d "")
      if echo "$output" | grep -q "Not Found"; then
        outputMessage="The asset number $textentered was not found"
      else
        outputMessage="Passcode for $myName cleared"
      fi
    fi
    if [ "$actionentered" == "Send a Lock Message" ]; then
      input=$($dialog -d -o -p -h --json --title "Lock Screen Message" --message "Enter a message" --textfield "Message")
      lockmessage=$(echo $input | $jq --raw-output '.Message')
      #lets send the lock message substituting + when there is a " " in the message
      output=$(curl -k -H "Authorization: Bearer $token" ${jssAddress}/JSSResource/mobiledevicecommands/command/DeviceLock/"${lockmessage// /+}"/id/"$myID" -X POST -d "")
      if echo "$output" | grep -q "Not Found"; then
        outputMessage="Could not send message. I am not so good with some punctuations"
      else
        outputMessage="Lock message sent to $myName"
      fi
    fi
    if [ "$actionentered" == "List Group Membership" ]; then #list groups
      myInfo=$(curl -H "Accept: application/json" -s -H "Authorization: Bearer $token" -X GET ${jssAddress}/JSSResource/mobiledevices/id/"$myID")
      groupcount=$(echo "$myInfo" | $jq '.mobile_device.mobile_device_groups|length')
      i=0
      listofgroups=""
      while [ $i -lt "$groupcount" ]; do
        groupname=$(echo "$myInfo" | $jq --raw-output --argjson i ${i} '.mobile_device.mobile_device_groups[$i].name')
        listofgroups+="  \n${groupname}"
        let i=i+1
      done
      outputMessage="$myName is a member of the following groups $listofgroups"
    fi
    if [ "$actionentered" == "List Configuration Profiles" ]; then
      myInfo=$(curl -H "Accept: application/json" -s -H "Authorization: Bearer $token" -X GET ${jssAddress}/JSSResource/mobiledevices/id/"$myID")
      profilecount=$(echo "$myInfo" | $jq '.mobile_device.configuration_profiles|length')
      i=0
      listofprofiles=""
      while [ $i -lt "$profilecount" ]; do
        profilename=$(echo "$myInfo" | $jq --raw-output --argjson i ${i} '.mobile_device.configuration_profiles[$i].display_name')
        listofprofiles+="  \n${profilename}"
        let i=i+1
      done
      outputMessage="$myName has the following profiles applied: $listofprofiles"
    fi
    if [ "$actionentered" == "List Installed Apps" ]; then
      myInfo=$(curl -H "Accept: application/json" -s -H "Authorization: Bearer $token" -X GET ${jssAddress}/JSSResource/mobiledevices/id/"$myID")
      appcount=$(echo "$myInfo" | $jq '.mobile_device.applications|length')
      i=0
      listofapps=""
      while [ $i -lt "$appcount" ]; do
        appname=$(echo "$myInfo" | $jq --raw-output --argjson i ${i} '.mobile_device.applications[$i].application_name')
        listofapps+="  \n${appname}"
        let i=i+1
      done
      outputMessage="$myName has the following $appcount apps installed: $listofapps"
    fi

    if [ "$actionentered" == "Wipe Device" ]; then
      $dialog -d -o -2 --title "Warning!" --message "Are you sure you want to wipe all data from $myName?" --icon warning
      if [ "$?" == "0" ]; then
        output=$(curl -k -H "Authorization: Bearer $token" ${jssAddress}/JSSResource/mobiledevicecommands/command/EraseDevice/id/"$myID" -X POST -d "")
        if echo "$output" | grep -q "Not Found"; then
          outputMessage="The asset number $textentered was not found"
        else
          outputMessage="$myName has been Erased!"
        fi
      fi
    fi

    if [ "$actionentered" == "Rename iPad to assigned username" ]; then
      myOutput=$(curl -H "Accept: application/json" -s -H "Authorization: Bearer $token" -X GET ${jssAddress}/JSSResource/mobiledevices/match/"$assettag")
      myUserName=$(echo "$myOutput" | $jq --raw-output '.mobile_devices[].realname')
      apiData="<mobile_device><general><display_name>$myUserName</display_name><device_name>$myUserName</device_name><name>$myUserName</name></general></mobile_device>"
      output=$(curl -sS -k -i -H "Authorization: Bearer $token" -X PUT -H "Content-Type: text/xml" -d "<?xml version=\"1.0\" encoding=\"ISO-8859-1\"?>$apiData" ${jssAddress}/JSSResource/mobiledevices/id/"$myID")
      #send command to rename the device
      output=$(curl -k -H "Authorization: Bearer $token" ${jssAddress}/JSSResource/mobiledevicecommands/command/DeviceName/"${myUserName// /+}"/id/"$myID" -X POST -d "")
      if echo "$output" | grep -q "Unable to match"; then
        outputMessage="The asset number $textentered was not found"
      else
        outputMessage="$myName has been renamed to $myUserName"
        myName=$myUserName
      fi
    fi

    if [ "$actionentered" == "Rename iPad" ]; then
      input=$($dialog -d -o -p -h --json --title "Rename iPad" --textfield "iPad Name" --message "Enter the name to assign")
      myUserName=$(echo $input | $jq --raw-output '."iPad Name"')
      apiData="<mobile_device><general><display_name>$myUserName</display_name><device_name>$myUserName</device_name><name>$myUserName</name></general></mobile_device>"
      output=$(curl -sS -k -i -H "Authorization: Bearer $token" -X PUT -H "Content-Type: text/xml" -d "<?xml version=\"1.0\" encoding=\"ISO-8859-1\"?>$apiData" ${jssAddress}/JSSResource/mobiledevices/id/"$myID")
      #send command to rename the device
      output=$(curl -k -H "Authorization: Bearer $token" ${jssAddress}/JSSResource/mobiledevicecommands/command/DeviceName/"${myUserName// /+}"/id/"$myID" -X POST -d "")
      if echo "$output" | grep -q "Unable to match"; then
        outputMessage="The asset number $textentered was not found"
      else
        outputMessage="$myName has been renamed to $myUserName"
        myName=$myUserName
      fi
    fi

    if [ "$actionentered" == "Remove from all groups" ]; then #list groups
      myInfo=$(curl -H "Accept: application/json" -s -H "Authorization: Bearer $token" -X GET ${jssAddress}/JSSResource/mobiledevices/id/"$myID")
      groupcount=$(echo "$myInfo" | $jq '.mobile_device.mobile_device_groups|length')
      i=0
      apiData="<mobile_device_group><mobile_device_deletions><mobile_device><id>$myID</id></mobile_device></mobile_device_deletions></mobile_device_group>"
      listofgroups=""
      while [ $i -lt "$groupcount" ]; do
        groupnumber=$(echo "$myInfo" | $jq --argjson i ${i} '.mobile_device.mobile_device_groups[$i].id')
        groupname=$(echo "$myInfo" | $jq --raw-output --argjson i ${i} '.mobile_device.mobile_device_groups[$i].name')
        output=$(curl -sS -k -i -H "Authorization: Bearer $token" -X PUT -H "Content-Type: text/xml" -d "<?xml version=\"1.0\" encoding=\"ISO-8859-1\"?>$apiData" ${jssAddress}/JSSResource/mobiledevicegroups/id/"$groupnumber")
        listofgroups+="  \n${groupname}"
        let i=i+1
      done
      outputMessage="$myName removed from the following groups: $listofgroups"
    fi

    if [ "$actionentered" == "Update Asset Number" ]; then
      input=$($dialog -d -o -p -h --json --title "Asset Tag" --textfield "Asset number" --message "Enter the new asset number")
      newasset=$(echo $input | $jq --raw-output '."Asset number"')
      #set asset tag
      apiData="<mobile_device><general><asset_tag>$newasset</asset_tag></general></mobile_device>"
      curl -sS -k -i -H "Authorization: Bearer $token" -X PUT -H "Content-Type: text/xml" -d "<?xml version=\"1.0\" encoding=\"ISO-8859-1\"?>$apiData" ${jssAddress}/JSSResource/mobiledevices/id/"$myID"
      outputMessage="$assettag was given asset number $newasset"
    fi
    if [ "$actionentered" == "Open JAMF page" ]; then
      open "${jssAddress}/mobileDevices.html?id=$myID"
      outputMessage="Page opened for $myName"
    fi

    if [ "$actionentered" == "Add to a Group" ]; then
      allGroups=$(curl -H "Accept: application/json" -s -H "Authorization: Bearer $token" -X GET ${jssAddress}/JSSResource/mobiledevicegroups)
      staticGroups=$(echo $allGroups | $jq '.mobile_device_groups[]|select(.is_smart==false).id')
      conftemp=""
      for i in ${staticGroups}; do
        groupName=$(echo $allGroups | $jq --raw-output --argjson id ${i} '.mobile_device_groups[]|select(.id==$id).name')
        conftemp=$conftemp",$groupName"
      done
      input=$($dialog -d -o -2 -p -h --json --title "Add to Group" --message "Select the group" --selecttitle "Group Name" --selectvalues "$conftemp")
      [ "$?" -eq 2 ] && exit 1
      selectedGroup=$(echo $input | $jq --raw-output '.SelectedOption')
      groupNumber=$(echo $allGroups | $jq --arg name "$selectedGroup" '.mobile_device_groups[]|select(.name==$name).id')
      apiData="<mobile_device_group><mobile_device_additions><mobile_device><id>$myID</id></mobile_device></mobile_device_additions></mobile_device_group>"
      output=$(curl -sS -k -i -H "Authorization: Bearer $token" -X PUT -H "Content-Type: text/xml" -d "<?xml version=\"1.0\" encoding=\"ISO-8859-1\"?>$apiData" ${jssAddress}/JSSResource/mobiledevicegroups/id/$groupNumber)
      if echo "$output" | grep -q "Unable to match"; then
        outputMessage="The asset number $textentered was not found"
      else
        outputMessage="$myName has been added to the $selectedGroup group"
      fi
    fi

    if [ "$actionentered" == "Remove from a Group" ]; then
      myInfo=$(curl -H "Accept: application/json" -s -H "Authorization: Bearer $token" -X GET ${jssAddress}/JSSResource/mobiledevices/id/"$myID")
      myGroups=$(echo $myInfo | $jq '.mobile_device.mobile_device_groups[]')
      myGroupNames=$(echo $myGroups | $jq --raw-output '.name')
      conftemp=""
      oldIFS="$IFS"
      IFS=$'\n'
      for i in ${myGroupNames}; do
        conftemp=$conftemp",$i"
      done
      IFS="$oldIFS"
      input=$($dialog -d -o -2 -p -h --json --title "Remove from Group" --message "Select the group" --selecttitle "Group Name" --selectvalues "$conftemp")
      [ "$?" -eq 2 ] && exit 1
      selectedGroup=$(echo $input | $jq --raw-output '.SelectedOption')
      groupNumber=$(echo $myGroups | $jq --arg name "$selectedGroup" 'select(.name==$name).id')
      apiData="<mobile_device_group><mobile_device_deletions><mobile_device><id>$myID</id></mobile_device></mobile_device_deletions></mobile_device_group>"
      output=$(curl -sS -k -i -H "Authorization: Bearer $token" -X PUT -H "Content-Type: text/xml" -d "<?xml version=\"1.0\" encoding=\"ISO-8859-1\"?>$apiData" ${jssAddress}/JSSResource/mobiledevicegroups/id/$groupNumber)
      if echo "$output" | grep -q "Unable to match"; then
        outputMessage="The asset number $textentered was not found"
      else
        outputMessage="$myName has been removed from the $selectedGroup group"
      fi
    fi

  done

done

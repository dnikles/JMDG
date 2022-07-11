getCreds() {

  #set username, password, and JSS location
  jssAddress=""
  jssAPIUsername=${USER}
  savePW=0
  while (true); do
    #read the password if it exists, otherwise get a new password
		#If you want to hardcode the password, uncomment the following line and comment out the next 5 lines.
		#jssAPIPassword="enter password here"
    if ! jssAPIPassword=$(security find-generic-password -a ${jssAPIUsername} -s jamfscripts -w); then
      input=$($dialog -d -o -p -h --title "JAMF password" --message "Please enter the JAMF password for ${jssAPIUsername}" --textfield Password,secure,required --json --checkbox "Save Password")
      jssAPIPassword=$(echo $input | $jq --raw-output .Password)
      savePW=$(echo $input | $jq '."Save Password"')
    fi
    #now test the password
    myOutput=$(curl -H "Accept: application/json" -su ${jssAPIUsername}:"$jssAPIPassword" -X POST ${jssAddress}/api/v1/auth/token)

    if echo "$myOutput" | grep -q "errors"; then
      $dialog -d -o --title "Wrong password" --message "The password is incorrect" --icon warning
      security delete-generic-password -a ${jssAPIUsername} -s jamfscripts
    else
      if [ $savePW == "true" ]; then
        security add-generic-password -a ${jssAPIUsername} -s jamfscripts -w "$jssAPIPassword"
      fi
			token=$(echo $myOutput | $jq --raw-output '.token')
			expiration=$(echo $myOutput | $jq --raw-output '.expires')
			expiration=${expiration%.*}
			expiration_seconds=$(date -u -j -f "%FT%T" "$expiration" '+%s')
      break
    fi
  done
}

checkExpiration() {
  current=$(date +%s)
  time_left=$((($expiration_seconds - $current) / 60))
  if [ $time_left -lt 0 ]; then
    #token is expired
    getCreds
  elif [ $time_left -lt 2 ]; then
    #token will expire soon
    renewToken
  fi
}

renewToken() {
  myOutput=$(curl -s -H "Accept: application/json" -H "Authorization: Bearer $token" -X POST ${jssAddress}/api/v1/auth/keep-alive)
  token=$(echo $myOutput | $jq --raw-output '.token')
  expiration=$(echo $myOutput | $jq --raw-output '.expires')
  expiration=${expiration%.*}
  expiration_seconds=$(date -u -j -f "%FT%T" "$expiration" '+%s')
}

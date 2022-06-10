# JMDG
 JAMF Mobile Device GUI

 These scripts allows you to quickly perform actions on a mobile device in Jamf. You can retrieve information about the device, add to or remove from groups, erase the device, enter lost mode, rename, etc. Using this tool is much faster than doing any of these tasks through the web interface. [swiftDialog](https://github.com/bartreardon/swiftDialog) and [jq](https://github.com/bartreardon/swiftDialog) are required.


 ## Configuration
 Download getCredsSwift.sh and jmdg.sh, and make them executable.

Edit getCredsSwift.sh and enter the address for your jamf server (for example, https://jamf.domain.com:8443 or https://company.jamfcloud.com .) By default the script uses the current username to log in to jamf, but you can hardcode it on the jssAPIUsername= line.

Edit jmdg.sh to set the locations of the jq and dialog binaries.

## Usage
Just run jmdg.sh

It calls functions in getCredsSwift.sh, which get your jamf credentials, test them against your jamf server, get an authorization token, and check and renew the token's expiration. It will optionally save the password in your keychain. After that, all of the actions are presented in a drop down menu.


 ![Available Actions](/images/choices.png "Available actions")

 ![Warning Message](/images/warning.png "Warning. message")

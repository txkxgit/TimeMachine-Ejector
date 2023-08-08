##################################################################
# TimeMachine Ejector
#
# Allows to eject a TimeMachine Volume with a single click
#
#
# Timo Kahle
# 2015-08-17
#
# Changes
# v1.0 (2015-08-23)
# o Initial version
#
# v1.1 (2016-02-02)
# o Renamed to TimeMachine Ejector
# + Added Min OS X version check
# + Added checks if TimeMachine Backup configured and available
# + Added function to stop TimeMachine Backup if it is running when an Eject is triggered
#
# v1.2 (2016-07-10)
# o Changed Button labels
# o Renamed Quit Button to "Continue" as "Quit" was misleading
# o Exchanged application icons
# - Removed debug output
#
# v1.2.1 (2018-05-22)
# + Added dialog if not TM device is connected for improved user convenience
# + Added "activate" statement before displaying dialogs
#
# v1.2.2 (2018-06-06)
# + Added function to close TM System Preference Pane if open
#
# 
# ToDo
# + Support for multiple TimeMachine Volumes
# + Support for networked TimeMachine Volumes
#
##################################################################

# Variables and Constants
property APP_NAME : "TimeMachine Ejector"
property APP_VERSION : "1.2.1"
property APP_ICON : "applet.icns"
property APP_ICON_INFO : "TimeMachine Ejector_info.icns"
property APP_ICON_ERROR : "TimeMachine Ejector_error.icns"

property TIMEOUT_SEC : 3600 -- 60 minutes

# OS X Version check details
property OSX_VERSION_MIN : "10.9"

# Maintenance shell commands (require admin privileges)
property CMD_TM_DESTINATIONINFO : "tmutil destinationinfo"
property RES_TM_NO_DESTINATION : "tmutil: No destinations configured"
property CMD_TM_VOLUME : "tmutil destinationinfo | grep 'Mount Point' | sed 's/.*: //'"
property CMD_TM_IDENTIFY : "tmutil destinationinfo | grep 'Volume' | awk '{ print $4 }'"
property CMD_TM_EJECT : "diskutil unmountDisk "
property CMD_TM_STOP : "tmutil stopbackup"
property RES_TM_RUNNING_INDICATOR : "Running = 1"
property CMD_TM_RUNNING : "tmutil status"
property CMD_TM_PREFPANE_EXIT : "killall -9 'System Preferences'"

# Button texts
property BTN_OK : "OK"
property BTN_EXIT : "Exit"
property BTN_CONTINUE : "Continue"
property BTN_QUIT : "Quit"
property BTN_STOP_EJECT : "Stop & Eject"
property BTN_EJECT_LATER : "Eject Later"


##################################################################


# Main
on run
	# Define the app icon for dialogs
	set dlgIcon to (path to resource APP_ICON)
	set dlgIconInfo to (path to resource APP_ICON_INFO)
	set dlgIconError to (path to resource APP_ICON_ERROR)
	set dlgTitle to APP_NAME & " (" & APP_VERSION & ")"
	
	# Helpers
	set isConfiguredTMVol to false
	set isMountedTMVol to false
	set isRunningTM to false
	
	# Resources
	set dlg_Notification_Subtitle_StartTM to "TM Eject"
	set dlg_Notification_Subtitle_StartTM to "TM Stop"
	set dlg_Notification_Subtitle_Info to "Info"
	set dlg_Info_TM_Running to "A TimeMachine Backup is currently running. Do you want to STOP it or leave it running and QUIT?"
	set dlg_Info_TM_Ejected to "Your TimeMachine Volume was ejected."
	set dlg_Info_TM_Stopped_Ejected to "Your TimeMachine Backup was stopped and the Volume ejected."
	set dlg_Info_NoTM_Connected to "No TimeMachine Volume connected."
	
	
	# Check OS X Version for compatibility
	if OSXVersionSupported() is false then
		activate
		display dialog dlg_Info_OSVersion_Check_Failed & return with title dlgTitle buttons {BTN_OK} default button {BTN_OK} cancel button {BTN_OK} with icon dlgIconError
	end if
	
	
	# Get details on TimeMachine Volume
	set theTMVolume to ExecCommand(CMD_TM_IDENTIFY)
	
	# TimeMachine Volume is mounted
	if theTMVolume is not "" then
		
		# Check if TimeMachine Backup is running
		set isRunningTM to ExecCommand(CMD_TM_RUNNING)
		if isRunningTM contains RES_TM_RUNNING_INDICATOR then
			set isRunningTM to true
			
			
			# TODO: Later add option "Let finish, then eject..."; +BTN_EJECT_LATER
			
			# TimeMachine is currently running, so we offer to stop and eject it
			activate
			set theAction to display dialog dlg_Info_TM_Running with title dlgTitle buttons {BTN_CONTINUE, BTN_STOP_EJECT} default button {BTN_STOP_EJECT} cancel button {BTN_CONTINUE} with icon dlgIconInfo
			set retVal to button returned of theAction
			if retVal is BTN_STOP_EJECT then
				set stopTMJob to ExecCommand(CMD_TM_STOP)
				delay 4
				set ejectTM to TMEject(CMD_TM_EJECT, theTMVolume)
				
				# Close the TM System Preferences Pane if it's open
				try
					set closePrefPane to ExecCommand(CMD_TM_PREFPANE_EXIT)
				on error errMsg
					# Nothing
				end try
				# TODO
				# +Add check if command passed properly
				# Inform that TimeMachine Volume was ejected
				display notification dlg_Info_TM_Stopped_Ejected as text with title dlgTitle subtitle dlg_Notification_Subtitle_Info
			else
				# Quit
				return
			end if
			
		else
			# TimeMachine is not running, so we directly eject the Volume
			set ejectTM to TMEject(CMD_TM_EJECT, theTMVolume)
			# TODO
			# +Add check if command passed properly
			# Inform that TimeMachine Volume was ejected
			
			# Close the TM System Preferences Pane if it's open
			try
				set closePrefPane to ExecCommand(CMD_TM_PREFPANE_EXIT)
			on error errMsg
				# Nothing
			end try
			
			# Inform that TimeMachine Volume was ejected
			display notification dlg_Info_TM_Ejected as text with title dlgTitle subtitle dlg_Notification_Subtitle_Info
		end if
		
	else
		# Inform that no TimeMachine connected
		display notification dlg_Info_NoTM_Connected as text with title dlgTitle subtitle dlg_Notification_Subtitle_Info
		
		activate
		display dialog dlg_Notification_Subtitle_Info & return & return & dlg_Info_NoTM_Connected with title dlgTitle buttons {BTN_EXIT} default button {BTN_EXIT} cancel button {BTN_EXIT} with icon dlgIconInfo
	end if
	
end run


##################################################################
# Helper functions
##################################################################

# Run a command without admin privileges
on ExecCommand(thisAction)
	
	try
		#Introduce timeout to prevent timing out of large transfers
		with timeout of TIMEOUT_SEC seconds
			#set returnValue to do shell script (thisAction & " 2>&1") with administrator privileges
			#set returnValue to do shell script (thisAction & " 2>&1")
			set returnValue to do shell script (thisAction)
		end timeout
		
		return returnValue
	on error errMsg
		if errMsg contains "no such file" then
			return "Warning: " & errMsg
		else
			return "Error: " & errMsg
		end if
	end try
end ExecCommand



# Eject a TimeMachine Volume
on TMEject(cmd_Eject, theVolume)
	set myEjectTM to ExecCommand(cmd_Eject & theVolume)
	# No errors
	if myEjectTM contains "successful" then
		return true
	else
		return false
	end if
end TMEject


# Check if TimeMachine Backup configured
on IsConfiguredTM()
	set tm_Config to do shell script CMD_TM_DESTINATIONINFO
	
	if tm_Config does not contain RES_TM_NO_DESTINATION then
		return true
	else
		return false
	end if
end IsConfiguredTM


# Get TimeMachine Volume and check if it is mounted
on IsMountedTM()
	set tm_Mounted to do shell script CMD_TM_VOLUME
	
	if tm_Mounted is not "" then
		return true
	else
		return false
	end if
end IsMountedTM


# Valid OS X version
on OSXVersionSupported()
	set strOSXVersion to system version of (system info)
	considering numeric strings
		set IsSupportedOSXVersion to strOSXVersion is greater than or equal to OSX_VERSION_MIN
	end considering
	
	return IsSupportedOSXVersion
end OSXVersionSupported


# Handle onQuit events
on quit
	return
end quit
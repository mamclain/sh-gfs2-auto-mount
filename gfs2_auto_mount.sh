#!/bin/bash
# A servicectl service script to check the status of gfs2 and mount a target folder

major_version=1
minor_version=0

# a flag for debug messages
debug=0
mode=1


# debug print
message () {
  if [ "$debug" -eq 1 ]
  then
    echo "$1"
  fi
}

# check to see if we have coresync
have_corosync() {
  corosync_system_status=$(systemctl status corosync 2>&1 >/dev/null | grep -q "not be found" && [ $? -eq 0 ] && echo "No" || echo "Yes")
  if [ "$corosync_system_status" = "Yes" ]
  then
    return 1
  else
    return 0
  fi
}

# corosync status check
corosync_status() {
  corosync_state=$(systemctl status corosync | grep Active: | awk '{print $2}')
  if [ "$corosync_state" = "active" ]
  then
    return 1
  else
    return 0
  fi
}

# corosync quorum check
corosync_quorum() {
  quorate_state=$(corosync-quorumtool | grep Quorate: | awk '{ print substr($0, index($0,$2)) }')
  message "Quorate: $quorate_state"
  if [ "$quorate_state" == "Yes" ]
  then
    return 1
  else
    return 0
  fi
}


# check to see if we have dlm
have_dlm(){
  dlm_system_status=$(systemctl status dlm 2>&1 >/dev/null | grep -q "not be found" && [ $? -eq 0 ] && echo "No" || echo "Yes")
  if [ "$dlm_system_status" = "Yes" ]
  then
    return 1
  else
    return 0
  fi
}

# dlm status check
dlm_status() {
  dlm_state=$(systemctl status dlm | grep Active: | awk '{print $2}')
  if [ "$dlm_state" = "active" ]
  then
    return 1
  else
    return 0
  fi
}


# check to see if we have open-iscsi
have_open_iscsi(){
  open_iscsi_system_status=$(systemctl status open-iscsi 2>&1 >/dev/null | grep -q "not be found" && [ $? -eq 0 ] && echo "No" || echo "Yes")
  if [ "$open_iscsi_system_status" = "Yes" ]
  then
    return 1
  else
    return 0
  fi
}

# dlm status check
open_iscsi_status() {
  open_iscsi_state=$(systemctl status open-iscsi | grep Active: | awk '{print $2}')
  if [ "$open_iscsi_state" = "active" ]
  then
    return 1
  else
    return 0
  fi
}


# is block device status check
block_device_exists() {
  if [ -b "$1" ]
  then
    return 1
  else
    return 0
  fi
}

# folder exists
folder_exists() {
  if [ -d "$1" ]
  then
    return 1
  else
    return 0
  fi
}


# entry point with args
while getopts d:m:vhu flag
do
    case "${flag}" in
        d) 
          device=${OPTARG}
        ;;
        m)
          mount=${OPTARG}
        ;;
        v)
          debug=1
        ;;
        u)
          mode=2
        ;;
        h)
          echo "GFS2 Auto Mount V$major_version.$minor_version By Mike Mclain"
          echo "-d    The Input GFS2 Device"
          echo "-m    The Output Folder to Mount"
          echo "-v    Show Debug to Output"
          echo "-u    Used by execstop flag to unmount the gfs2 mount if mounted"
          echo "-h    This Help Message"
          exit
        ;;
    esac
done

# check if the user passed in a mount
if [ -z "$mount" ]
then
  echo "No Mount Path Found"  
  exit
fi

# check if mount folder exisits
if folder_exists $mount -eq 0
then
  echo "Mount folder $mount does not exists"
  exit
fi


# check if mount is mounted
is_mountpoint=$(mountpoint $mount | grep not)
if [ -z "$is_mountpoint" ]
then
  # if so, check mode to see if we are unmount or error
  if [ "$mode" -eq 1 ]
  then
    echo "Mount folder $mount is already mounted"
    exit
  else
    echo "Script called via -u, will unmount $mount"  
    umount $mount
    exit
  fi
else
  # catch a non mount case of script stop mode
  if [ "$mode" -eq 2 ]
  then
      echo "Script called via -u, Mount $mount was not mounted"  
      exit
  fi
fi

  
# check if a user passed in a device
if [ -z "$device" ]
then
  echo "No Device Path Found"  
  exit
fi


# check for corosync
check_corosync=$(which corosync-quorumtool)

if [ -z "$check_corosync" ]
then
  echo "corosync-quorumtool not found"  
  exit
fi

# check for dlm_tool
check_dlm_tool=$(which dlm_tool)

if [ -z "$check_dlm_tool" ]
then
  echo "dlm_tool not found"  
  exit
fi

# check for iscsiadm
check_iscsiadm=$(which iscsiadm)

if [ -z "$check_iscsiadm" ]
then
  echo "iscsiadm not found"  
  exit
fi

# check for service in systemctl for corosync
if have_corosync -eq 0
then
  echo "Corosync not found in systemctl"
  exit
fi

# check for service in systemctl for dlm
if have_dlm -eq 0
then
  echo "dlm not found in systemctl"
  exit
fi

# check for service in systemctl for open_iscsi
if have_open_iscsi -eq 0
then
  echo "open_iscsi not found in systemctl"
  exit
fi


# wait for corosync start
message "Wait on Corosync Start"
while corosync_status -eq 0;
do
 /usr/bin/sleep 5;
done
message "Corosync Is Online"

# check for quorum
message "Wait on Corosync Quorum"
while corosync_quorum -eq 0;
do
 /usr/bin/sleep 5;
done
message "Corosync Quorum Online"

# wait for dlm start
message "Wait on dlm Start"
while dlm_status -eq 0;
do
 /usr/bin/sleep 5;
done
message "dlm Is Online"

# wait for open_iscsi start
message "Wait on open iscsi Start"
while open_iscsi_status -eq 0;
do
 /usr/bin/sleep 5;
done
message "open iscsi Is Online"


# wait for the Device mount
message "Wait on Device $device"
while block_device_exists $device -eq 0;
do
 /usr/bin/sleep 5;
done
message "Device $device Is Online"



# at this point lets try to mount
message "Try to mount $device to $mount"
mount $device $mount





 

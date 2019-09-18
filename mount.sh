#!/bin/bash
#################################################
#
# Usage:
#   Making a filesystem from a block device 
#   and mount it on provided mount point
#
# Arguments:
#   $1: Mountpoint directory path
#
# Returns:
#   0: Sucessfully mounted
#   1: Provided Mountpoint already has been used 
#  -1: There's no block device which can be used
#
##################################################


IFS=$'\n'
MOUNT_POINT=$1
FILE_SYSTEM="xfs"


device_list=(`dmesg | grep SCSI | grep -o sd[a-z]`)
device_path=()

for item in ${device_list[@]}; do
   device_path+=("/dev/"${item})
done

partition_path=(`fdisk -l | grep -v swap | egrep -o /dev/sd.[0-9]+ | sed -e 's/[0-9]//g'` )

partition_path=($(echo "${partition_path[*]}" | sort | uniq ) )

both=( `{ echo "${device_path[*]}"; echo "${partition_path[*]}"; } | sort | uniq -d`)
target_device=(`{ echo "${device_path[*]}"; echo "${both[*]}"; } | sort | uniq -u`)

mountpoint ${MOUNT_POINT}
if [ $? == 0 ]; then
  echo "## A filesystem already has been on provided mount point.##" >&2
  exit 1
fi

for item in ${target_device[*]}; do
    parted -s -a optimal ${item} mklabel gpt
    
    if [ $? != 0 ]; then
      echo "## A filesystem already has been used  ##"
      echo "## Search next block device ##"
      continue
    else
      parted -s -a optimal ${item} -- mkpart ${FILE_SYSTEM}  0% 100%
      device=${item}"1"

      mkfs -t ${FILE_SYSTEM} ${device}
      if [ ! -d ${MOUNT_POINT} ]; then
         mkdir ${MOUNT_POINT}
      fi
      echo "## mount a filesystem on a provided mountpoint ##"
      uuid=`blkid -o export ${device}  | grep ^UUID`
      mount ${device} ${MOUNT_POINT}
      echo ${uuid} ${MOUNT_POINT} ${FILE_SYSTEM} defaults,nofail 0 0 | tee -a /etc/fstab
      echo "## mount process has been successfully completed ##"
      exit 0
    fi
done

echo "There is no filesystem which can be mounted" >&2
exit -1

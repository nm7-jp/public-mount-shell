#!/bin/bash
IFS=$'\n'
MOUNT_POINT=("/data01" "/data02" "/data03")
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

i=0
for item in ${target_device[*]}; do
    parted -s -a optimal ${item} mklabel gpt
    parted -s -a optimal ${item} -- mkpart ${FILE_SYSTEM}  0% 100%
    device=${item}"1"

    mkfs -t ${FILE_SYSTEM} ${device}
    if [ ! -d ${MOUNT_POINT[${i}]} ]; then
       sudo mkdir ${MOUNT_POINT[${i}]}
    fi
    mountpoint ${MOUNT_POINT[${i}]}
    if [ $? != 0 ]; then
       echo "mount on mountpoint"
       uuid=`sudo blkid -o export ${device}  | grep ^UUID`
       mount ${device} ${MOUNT_POINT[${i}]}
       echo ${uuid} ${MOUNT_POINT[${i}]} ${FILE_SYSTEM} defaults,nofail 0 0 | tee -a /etc/fstab
    fi
    i+=1
done

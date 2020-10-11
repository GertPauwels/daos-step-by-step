#!/bin/bash
# Script verified on DAOS v1.0.1

# Variables used in this script
containerPATH=/mnt/mycontainer

# Check prerequisites
if ! command -v fio &> /dev/null
then
    echo "fio is a prerequisite"
    exit
fi

# Check if daos_agent is running
if $(pidof daos_agent >/dev/null) ; then
	echo "[OK] daos_agent is running" 
else
	echo "daos_agent is NOT running"
	exit
fi

# Check if OFI_INTERFACE is set when DAOS version 1.0 is used
echo "[OK] $(daos_server version)" 
if [[ $(daos_server version) == *"1.0."* ]]; then
	if [ -z "$OFI_INTERFACE" ]; then
		echo "OFI_INTERFACE empty, need to be set for DAOS v1.0.x"
	else
		echo "[OK] OFI_INTERFACE=$OFI_INTERFACE"
	fi
fi

# Unmount the path $containerPATH if it is mounted.
if [ $(df -h -t fuse.daos | grep ${containerPATH} | wc -l) -eq 1 ]; then
        # The directory $containerPATH is mounted.
        echo "${containerPATH} is mounted"
        # Unmount the directory $containerPATH.
        if $(fusermount -u ${containerPATH}) ; then
                echo "unmounted ${containerPATH}"
        fi
else
        echo "${containerPATH} was not mounted"
fi

# If the path exists remove the directory as 'daos container create' will fail.
if [ -d "${containerPATH}" ] ; then
        rm -rf ${containerPATH}
	echo "Remove ${containerPATH}"
fi

# Remove all pools from the DAOS system.
while [ $(dmg -i system list-pools | wc -l) -gt 2 ] ; do
        poolUUID=$(dmg -i system list-pools | tail -1 | awk '{ print $1}')
        if  $(dmg -i pool destroy --pool=${poolUUID} >/dev/null) ; then
                echo "pool ${poolUUID} destroyed"
        else
                echo "dmg -i pool destroy --pool=${poolUUID} failed"
        fi
done

# Create a pool 
# and parse the output of dmg -i pool create. Take the last line, take the 5th word and remove the dot.
poolUUID=$(dmg -i pool create --scm-size=30G --nvme-size=300G | tail -1 | awk '{ print $5 }' | sed 's/.$//')
# remove /n in the UUID string if there is any
poolUUID=${poolUUID//[$'\n']}
if [[  $? -eq 0 ]] ; then
        echo "pool ${poolUUID} created"
fi

# Create a POSIX container.
containerUUID=$(daos container create  --svc=0 --path=${containerPATH} --chunk_size=4K --type=POSIX --pool=${poolUUID} | tail -1 | awk '{ print $4 }')
if [[  $? -eq 0 ]] ; then
        echo "container ${containerUUID} created"
fi

if [[ $(daos_server version) == *"1.0."* ]]; then
	# dfuse need --pool and --cont for DAOS v1.0.x
	if dfuse --pool=${poolUUID} --cont=${containerUUID} --mountpoint=${containerPATH} --svc=0 ; then
	        echo "mounted with 'dfuse --pool=${poolUUID} --cont=${containerUUID} --mountpoint=${containerPATH} --svc=0'"
	fi
elif [[ $(daos_server version) == *"1."* ]]; then
	# dfuse does not need --pool and --cont for DAOS 1.1x or later
	if dfuse --mountpoint=${containerPATH} --svc=0 -f; then
	        echo "mounted with 'dfuse --mountpoint=${containerPATH} --svc=0 --foreground'"
	fi 
fi 

# Sleep a second. Calling df immediately after dfuse will not show the mounted directory.
sleep 1
# Show all filesystem with type 'fuse.daos'.
df -h -t fuse.daos
if [[ $? -gt 0 ]] ; then
	echo "No DAOS file system mounted with fuse"
	exit
fi

echo
echo "Running fio"
fio --name=random-write --ioengine=pvsync --rw=randwrite --bs=4k --size=128M --nrfiles=4 --directory=${containerPATH} --numjobs=8 --iodepth=16 --runtime=60 --time_based --direct=1 --buffered=0 --randrepeat=0 --norandommap --refill_buffers --group_reporting


# DAOS step-by-step guide: Part 3 - Setting up dfuse and test with fio
## Goal
Create a POSIX container in a pool and mount it.
Run fio on the mounted folder.
## Prerequisites
Have DAOS up and running on a single node. The steps in this document are the continuation of [Part 2 - Configuring SCM and NVMe](part2_modify_daos_server_yml_to_use_SCM_and_NVMe.md). It will also work on a running DAOS system on other Operating Systems or with a similar SCM and NVMe configuration.

A server system with Storage Class Memory e.g. Intel&reg; Optane&trade; Persistent Memory and a minimum one NVMe SSD is required.
## Create pool
```console
 $ dmg -i pool create --scm-size=30G --nvme-size=300G
```
Expected output:
		
	Pool-create command SUCCEEDED: UUID: fd3110dd-8ac2-495c-a21a-dbeecaa3be05, Service replicas: 0
Check existing pools:
```console
 $ dmg -i pool list
```
Expected output:

	Pool UUID                            Svc Replicas 
	---------                            ------------ 
	fd3110dd-8ac2-495c-a21a-dbeecaa3be05 0 	
## Create container
```console
 $ daos container create --svc=0 --path=/mnt/mycontainer --chunk_size=4K --type=POSIX --pool=fd3110dd-8ac2-495c-a21a-dbeecaa3be05
```
Expected output:
		
	Successfully created container 10857e43-5023-401d-b2be-3ba52c5afc1b type POSIX
## Mount
Mount the POSIX container with dfuse
```console
 $ dfuse --mountpoint=/mnt/mycontainer --svc=0 --pool=fd3110dd-8ac2-495c-a21a-dbeecaa3be05 --cont=10857e43-5023-401d-b2be-3ba52c5afc1b
```
Check with **df** if container is mounted
```console
 $ df -h -t fuse.daos
```
Expected output:

	Filesystem      Size  Used Avail Use% Mounted on
	dfuse           308G   13K  308G   1% /mnt/mycontainer
## Touch the mounted directory
The step is not necessary. If touching a file does not return an error, it means the directory is created and accessible.
```console
 $ touch /mnt/mycontainer/myfile
```

## Validate with fio
Any IO benchmark application will work.
The command below will run random write workload. It will write 1GB of data (8 x 128MB) and will do 4K Random Write blocks for 60 seconds.
```console
 $ fio --name=random-write --ioengine=pvsync --rw=randwrite --bs=4k --size=128M --nrfiles=4 --directory=/mnt/mycontainer --numjobs=8 --iodepth=16 --runtime=60 --time_based --direct=1 --buffered=0 --randrepeat=0 --norandommap --refill_buffers --group_reporting
```
Expected output:

	random-write: (g=0): rw=randwrite, bs=(R) 4096B-4096B, (W) 4096B-4096B, (T) 4096B-4096B, ioengine=libaio, iodepth=16
	...
	fio-3.7
	Starting 8 processes
	random-write: Laying out IO files (4 files / total 128MiB)
	random-write: Laying out IO files (4 files / total 128MiB)
	random-write: Laying out IO files (4 files / total 128MiB)
	random-write: Laying out IO files (4 files / total 128MiB)
	random-write: Laying out IO files (4 files / total 128MiB)
	random-write: Laying out IO files (4 files / total 128MiB)
	random-write: Laying out IO files (4 files / total 128MiB)
	random-write: Laying out IO files (4 files / total 128MiB)
	Jobs: 8 (f=32): [w(8)][100.0%][r=0KiB/s,w=35.8MiB/s][r=0,w=9155 IOPS][eta 00m:00s]
	random-write: (groupid=0, jobs=8): err= 0: pid=28511: Sat Sep 26 18:16:31 2020
	  write: IOPS=9535, BW=37.2MiB/s (39.1MB/s)(2235MiB/60002msec)
	    slat (usec): min=91, max=3503, avg=835.88, stdev=433.02
	    clat (usec): min=172, max=27894, avg=12580.75, stdev=1825.53
	     lat (usec): min=1289, max=28205, avg=13416.80, stdev=1920.58
	    clat percentiles (usec):
	     |  1.00th=[ 8094],  5.00th=[ 9503], 10.00th=[10159], 20.00th=[11076],
	     | 30.00th=[11731], 40.00th=[12125], 50.00th=[12649], 60.00th=[13173],
	     | 70.00th=[13566], 80.00th=[14091], 90.00th=[14877], 95.00th=[15401],
	     | 99.00th=[16450], 99.50th=[16909], 99.90th=[17695], 99.95th=[17957],
	     | 99.99th=[18744]
	   bw (  KiB/s): min= 4296, max= 5560, per=12.50%, avg=4766.63, stdev=302.03, samples=958
	   iops        : min= 1074, max= 1390, avg=1191.61, stdev=75.51, samples=958
	  lat (usec)   : 250=0.01%, 500=0.01%
	  lat (msec)   : 2=0.01%, 4=0.01%, 10=8.50%, 20=91.49%, 50=0.01%
	  cpu          : usr=0.41%, sys=1.38%, ctx=607518, majf=0, minf=392
	  IO depths    : 1=0.1%, 2=0.1%, 4=0.1%, 8=0.1%, 16=100.0%, 32=0.0%, >=64=0.0%
	     submit    : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
	     complete  : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.1%, 32=0.0%, 64=0.0%, >=64=0.0%
	     issued rwts: total=0,572175,0,0 short=0,0,0,0 dropped=0,0,0,0
	     latency   : target=0, window=0, percentile=100.00%, depth=16
	
	Run status group 0 (all jobs):
	  WRITE: bw=37.2MiB/s (39.1MB/s), 37.2MiB/s-37.2MiB/s (39.1MB/s-39.1MB/s), io=2235MiB (2344MB), run=60002-60002msec

# Shell script 
The  bash shell script [Part3 Setting up dfuse and test with fio](scripts/part3_setting_up_dfuse_and_test_with_fio.sh) does all the steps as described above and is listed below.
```bash
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

```

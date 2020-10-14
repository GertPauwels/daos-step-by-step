# DAOS step-by-step guide: Part 2 - Configuring SCM and NVMe
## Goal
Adding Storage Class Memory (SCM) and NVMe storage to a single node DAOS system.
## Prerequisites
Have DAOS up and running on a single node. The steps in this document are the continuation of [Part 1 - Setting up v1.0.1 on a single node on CentOS 7](part1_setting_up_single_node_on_CentOS_7.md), but will also work on a running DAOS system on other Operating Systems.

A server system with Storage Class Memory e.g. Intel&reg; Optane&trade; Persistent Memory and an minimum one NVMe SSD is required.
## Reset to default state
Open a terminal and run
```console
 $ daos_server storage prepare --reset
```
Expected output:

	Resetting locally-attached NVMe storage...
	Resetting locally-attached SCM...
	Memory allocation goals for SCM will be changed and namespaces modified, this will be a destructive operation. Please ensure namespaces are unmounted and locally attached SCM &  NVMe devices are not in use. Please be patient as it may take several minutes and subsequent reboot maybe required.
	Are you sure you want to continue? (yes/no)
	yes
	A reboot is required to process new memory allocation goals.
Reboot the system

## Configure Intel&reg; Optane&trade; PMem modules
```console
 $ ipmctl show -region
```
Expected output:
	
	There are no Regions defined in the system.
```console
 $ ipmctl create -goal
 ```
Expected output:
	
	The following configuration will be applied:
	 SocketID | DimmID | MemorySize | AppDirect1Size | AppDirect2Size
	==================================================================
 	 0x0000   | 0x0001 | 0.000 GiB  | 502.000 GiB    | 0.000 GiB
	 0x0001   | 0x1001 | 0.000 GiB  | 502.000 GiB    | 0.000 GiB
	Do you want to continue? [y/n] y
	Created following region configuration goal
 	 SocketID | DimmID | MemorySize | AppDirect1Size | AppDirect2Size
	==================================================================
	 0x0000   | 0x0001 | 0.000 GiB  | 502.000 GiB    | 0.000 GiB
	 0x0001   | 0x1001 | 0.000 GiB  | 502.000 GiB    | 0.000 GiB
	A reboot is required to process new memory allocation goals.
	
Reboot the system
```console
 $ ipmctl show -region
```
Expected output:

	 SocketID | ISetID             | PersistentMemoryType    | Capacity    | FreeCapacity | HealthState
	====================================================================================================
	 0x0000   | 0x2beada903e338a22 | AppDirectNotInterleaved | 502.000 GiB | 502.000 GiB  | Healthy
	 0x0001   | 0x7ffeda9060358a22 | AppDirectNotInterleaved | 502.000 GiB | 502.000 GiB  | Healthy
This system has only 1 Intel&reg; Optane&trade; PMem module per CPU.
```console
 $ ndclt list
```
This command will return nothing. There are namespace create yet after creating the regions.
```console
 $ ndctl create-namespace
```
Expected output:

	{
	  "dev":"namespace1.0",
	  "mode":"fsdax",
	  "map":"dev",
	  "size":"494.15 GiB (530.59 GB)",
	  "uuid":"bba427a5-2730-478f-bcec-07c188584643",
	  "sector_size":512,
	  "align":2097152,
	  "blockdev":"pmem1"
	}
As there are 2 CPUs in the system a second namespace need to be created. 
```console
 $ ndctl create-namespace
```
Expected output:

	{
	  "dev":"namespace0.0",
	  "mode":"fsdax",
	  "map":"dev",
	  "size":"494.15 GiB (530.59 GB)",
	  "uuid":"65767dee-9419-4ce8-a21f-5b80f8b4dfb6",
	  "sector_size":512,
	  "align":2097152,
	  "blockdev":"pmem0"
	}

```console
 $ daos_server storage prepare
```
Expected output:

	Preparing locally-attached NVMe storage...
	Preparing locally-attached SCM...
	SCM namespaces:
	                Device:pmem0 Socket:0 Capacity:531 GB
	                Device:pmem1 Socket:1 Capacity:531 GB

```console
 $ daos_server storage scan
```
Expected output:

	Scanning locally-attached storage...
	ERROR: /usr/bin/daos_admin EAL: No free hugepages reported in hugepages-1048576kB
	NVMe controllers and namespaces:
	                PCI:0000:5e:00.0 Model:INTEL SSDPE21K750GA  FW:E2010485 Socket:0 Capacity:750 GB
	                PCI:0000:5f:00.0 Model:INTEL SSDPE2KE016T8  FW:VDV10170 Socket:0 Capacity:1.6 TB
	                PCI:0000:d8:00.0 Model:INTEL SSDPE21K750GA  FW:E2010435 Socket:1 Capacity:750 GB
	                PCI:0000:d9:00.0 Model:INTEL SSDPE21K750GA  FW:E2010435 Socket:1 Capacity:750 GB
	SCM Namespaces:
	                Device:pmem0 Socket:0 Capacity:531 GB
	                Device:pmem1 Socket:1 Capacity:531 GB

If the Intel&reg; Optane&trade; PMem modules are used before it is a good idea to clean the devices after unmounting.
```console
 $ umount /dev/pmem*
 $ wipefs -a /dev/pmem*
```
## Edit the daos_server.yml file
Edit the **daos_server.yml** file in the directory **/etc/daos/**:

	  # For a single-server system
	  name: daos_server
	  access_points: ['localhost']

	  # port: 10001
	  provider: ofi+sockets
	  nr_hugepages: 4096
	  control_log_file: /tmp/daos_control.log
	  transport_config:
	    allow_insecure: true
	  servers:
	  -
	    targets: 1
	    first_core: 0
	    nr_xs_helpers: 0
	    fabric_iface: lo
	    fabric_iface_port: 31416
	    log_file: /tmp/daos_server.log
	    env_vars:
	    - DAOS_MD_CAP=1024
	    - CRT_CTX_SHARE_ADDR=0
	    - CRT_TIMEOUT=30
	    - FI_SOCKETS_MAX_CONN_RETRY=1
	    - FI_SOCKETS_CONN_TIMEOUT=2000
	   
	    scm_mount: /mnt/daos
  	    scm_class: dcpm
  	    scm_list: [/dev/pmem0]

  	    bdev_class: nvme
  	    bdev_list: ["0000:5e:00.0"]
### Storage Class Memory is added by the following part:

	    scm_mount: /mnt/daos
  	    scm_class: dcpm
  	    scm_list: [/dev/pmem0]
The value *dcpm* for **scm_class** defines Intel&reg; Optane&trade; Persistent Memory is used as SCM.

The value for **scm_mount** defines where the Intel&reg; Optane&trade; Persistent Memory will be mounted.

The value for **scm_list** is a list of linux devices. The output of **daos_server storage scan** shows this system has two Intel&reg; Optane&trade; Persistent Memory devices /dev/pmem0 and /dev/pmem1. Only one device will be configured here. For performance reasons it is recommended to configure a DAOS server instance with devices all connected to the same CPU. The **daos_server.yml** config file above has only one server definition part. The key **first_core** has value *0* indication this server definition part is configuring CPU0. In the output of **daos_server storage scan** it is shown that */dev/pmem0* is connected to CPU0.

### NMVe storage is added by the following part:

	    bdev_class: nvme
  	    bdev_list: ["0000:5e:00.0"]
The value *nvme* for **bdev_class** defines one or more NVMe devices are used.

The value for **scm_list** is a list of PCIe addresses of NVMe/PCIe devices. The output of **daos_server storage scan** shows this system has four NVMe SSD devices. Only one device will be configured here, but the list can contain more devices. In the output of **daos_server storage scan** it is shown that *0000:5e:00.0* and *0000:5f:00.0* are connected to CPU0. 

## Start DAOS server
Open a terminal and run 
```console
 $ daos_server start
```
 
## Format storage
Open a second terminal and run
```console
 $ dmg -i storage format
```

## Test DAOS system
In the second terminal, run:
```console
 $ daos_agent -i &
```
Expected output:
	
	Listening on /var/run/daos_agent/agent.sock
Hit *Enter key* to return to the command line.

The environment variable **OFI_INTERFACE** is need in the terminal in which you run a client application to tell the application which network interface to use:
```console
 $ export OFI_INTERFACE=lo
```
Start daos_test by running the following:
```console
 $ daos_test -m
```

# Next
Now that a DAOS server is running on a single node with SCM and NVMe configured a POSIX container can be created and mounted.
This is demonstrated in [Part 3 - Setting up dfuse and test with fio](part3_setting_up_dfuse_and_test_with_fio.md).

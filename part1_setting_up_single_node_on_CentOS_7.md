# DAOS step-by-step guide: Part 1 - Setting up v1.0.1 on a single node on CentOS 7
## Goal
Installing DAOS 1.0.1 from RPMs on CentOS 7 on a single node. Configure DAOS to use 16GB of RAM to emulate Storage Class Memory. Validate installation by running daos_test.

## Prerequisites
A server system with at least *16GB system memory* available. 

## Install CentOS 7
Download the official and up-to-date CentOS 7 ISO file, navigate to https://www.centos.org/download/.

Create a bootable USB medium from the ISO image.

Upon booting the CentOS 7 ISO file, you can begin the installation process.

Configure *Software Selection* and select *Server with GUI*. *Server with GUI* is used for the step-by-step guide, other selections are also possible.  

## Install DAOS from RPM
Log in into CentOS as **root** user.

All steps in this recipe can be executed by running the bash shell script [part1_setting_up_single_node_on_CentOS_7.sh](scripts/part1_setting_up_single_node_on_CentOS_7.sh) also available [below](#shellscript) in this document. 
### Download and install DAOS v1.0.1 RPMS
DAOS RPMs are available from the Intel<sup>&reg;</sup> Registration Center.
Clicking the [Intel<sup>&reg;</sup> Registration Center](https://registrationcenter.intel.com/forms/?productid=3412) link will take you to the registration center, where you will create an account. After creating an account, the following files can be downloaded:

- daos_debug.tar - _debuginfo_ packages
- daos_packages.tar - client and server main packages
- daos_source.tar - source RPMs

Run the following to install the DAOS repo on the system:
```console
 $ tar -C / -xf daos_packages.tar
 $ cp /opt/intel/daos_rpms/packages/daos_packages.repo /etc/yum.repos.d
 $ rm /opt/intel/daos_rpms/packages/libabt*
```
## Install EPEL for CentOS 7
Install Extra Packages for Enterprise Linux (EPEL), a set of additional packages for Enterprise Linux, including CentOS.
```console
 $ yum install epel-release
```
## Install daos-server and daos-client
Install both the **daos-server** and **daos-client** packages on this node. 
```console
 $ yum install daos-server
 $ yum install daos-client
```
## Install daos-tests package
```console
 $ yum install daos-tests
```
## Setup Non Persistent Default Runtime Directory
Only useful when DAOS  is started at this point script without rebooting, once reboot the none persistent step will be gone and only the results of the persistent steps will be there.
```console
 $ mkdir -p /var/run/daos_server
 $ chmod 0755 /var/run/daos_server
 $ chown root:root /var/run/daos_server

 $ mkdir -p /var/run/daos_agent
 $ chmod 0755 /var/run/daos_agent
 $ chown root:root /var/run/daos_agent
```
## Setup Persistent Default Runtime Directory
Create a **.conf** file in the **/etc/tmpfiles.d** directory that contains the following
 
	d /var/run/daos_server 0755 root root -
	d /var/run/daos_agent 0755 root root -
The systemd-tmpfiles utility will create at boot the directories **/var/run/daos_server** and **/var/run/daos/agent**
## Backup the original daos_server.yml file
The original daos_server.yml documents a lot of options, can be used as a reference.
Rename **/etc/daos/daos_server.yml** to **/etc/daos/daos_server.yml.original**
```console
 $ mv /etc/daos/daos_server.yml /etc/daos/daos_server.yml.original
```
## Create daos_server.yml file
Create a **daos_server.yml** file in the directory **/etc/daos/** with the following content:

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
	    # Storage definitions
	    # When scm_class is set to ram, tmpfs will be used to emulate SCM.
	    # The size of ram is specified by scm_size in GB units.
	    scm_mount: /mnt/daos # map to -s /mnt/daos
	    scm_class: ram
	    scm_size: 16

## Start DAOS server
Open a terminal and run 
```console
 $ daos_server start
```
Expected output:
		
	daos_server logging to file /tmp/daos_control.log
	ERROR: /usr/bin/daos_admin EAL: No free hugepages reported in hugepages-1048576kB
	DAOS Control Server (pid 17372) listening on 0.0.0.0:10001
	Waiting for DAOS I/O Server instance storage to be ready...
	SCM format required on instance 0
Note:
- The **ERROR** in the expected output can be ignored. This not and error, but a warning from SPDK.	 
## Format storage
Open a second terminal and run
```console
 $ dmg -i storage format
```
Expected output on the second terminal:

	localhost:10001: connected
	localhost: storage format ok
Expected output on the first terminal:

	formatting storage for DAOS I/O Server instance 0 (reformat: true)
	Starting format of SCM (ram:/mnt/daos)
	Finished format of SCM (ram:/mnt/daos)
	Starting format of file block devices (/tmp/daos-bdev)
	Finished format of file block devices (/tmp/daos-bdev)
	DAOS I/O Server instance 0 storage ready
	SCM @ /mnt/daos: 17 GB Total/17 GB Avail
	Starting I/O server instance 0: /usr/bin/daos_io_server
	daos_io_server:0 Using legacy core allocation algorithm
	daos_io_server:0 Starting SPDK v19.04.1 / DPDK 19.02.0 initialization...
	[ DPDK EAL parameters: daos -c 0x1 --log-level=lib.eal:6 --base-virtaddr=0x200000000000 --match-allocations --file-prefix=spdk22316 --proc-type=auto ]
	ERROR: daos_io_server:0 EAL: No free hugepages reported in hugepages-1048576kB
	Management Service access point started (bootstrapped)
	daos_io_server:0 DAOS I/O server (v1.0.1) process 23544 started on rank 0 with 1 target, 0 helper XS per target, firstcore 0, host localhost.localdomain.
Note:
- Use the -i option to connect without using certificates. The option is needed as there are no certificates generated yet. daos_server is configured to accept insecure connection by having

	  allow_insecure: true
  under *transport_config:* in the **/etc/daos/daos_server.yml** configuration file.
- The **ERROR** in the expected output can be ingnored. This not and error, but a warning from SPDK.
## Test DAOS system
In the second terminal, run:
```console
 $ daos_agent -i &
```
Expected output:
	
	Listening on /var/run/daos_agent/agent.sock
Hit *Enter key* to return to the command line.

Note:
- Use the -i option to connect without using certificates. The option is needed as there are no certificates generated yet.
- The & is needed to run **daos_agent** in the background.

The environment variable **OFI_INTERFACE** is need in the terminal in which you run a client application to tell the application which network interface to use:
```console
 $ export OFI_INTERFACE=lo
```
Start daos_test by running the following:
```console
 $ daos_test -m
```
Expected output:
	
	=================
	DAOS management tests..
	=====================
	[==========] Running 5 test(s).
	[ RUN      ] MGMT1: create/destroy pool on all tgts
	creating pool synchronously ... success uuid = 1dbed2e7-fadd-4b5f-80c5-e57c7e9e8b01
	destroying pool synchronously ... success
	[       OK ] MGMT1: create/destroy pool on all tgts
	[ RUN      ] MGMT2: create/destroy pool on all tgts (async)
	creating pool asynchronously ... success uuid = f8dd26b0-6d67-4b11-8104-c77103dcc9ba
	destroying pool asynchronously ... success
	[       OK ] MGMT2: create/destroy pool on all tgts (async)
	[ RUN      ] MGMT3: list-pools with no pools in sys
	success t0: output npools=0
	verifying pools[0..10], nfilled=0
	success t1: pools[] over-sized
	success t2: npools=0, non-NULL pools[] rc=0
	success t3: in &npools NULL, -DER_INVAL
	success
	[       OK ] MGMT3: list-pools with no pools in sys
	[ RUN      ] MGMT4: list-pools with multiple pools in sys
	setup: creating pool, SCM size=1 GB, NVMe size=2 GB
	setup: created pool b9033daa-3f64-448e-ab6f-5c8532445718
	setup: creating pool, SCM size=1 GB, NVMe size=2 GB
	setup: created pool cf897c43-672f-4951-883f-3ed3f88fd710
	setup: creating pool, SCM size=1 GB, NVMe size=2 GB
	setup: created pool aa31f356-05df-468e-a8e3-27e74f917047
	setup: creating pool, SCM size=1 GB, NVMe size=2 GB
	setup: created pool 87742e1b-2370-4207-8455-9875a7f98301
	success t0: output npools=4
	verifying pools[0..14], nfilled=4
	pool cf897c43-672f-4951-883f-3ed3f88fd710 found in list result
	pool aa31f356-05df-468e-a8e3-27e74f917047 found in list result
	pool b9033daa-3f64-448e-ab6f-5c8532445718 found in list result
	pool 87742e1b-2370-4207-8455-9875a7f98301 found in list result
	success t1: pools[] over-sized
	success t2: npools=0, non-NULL pools[] rc=0
	success t3: in &npools NULL, -DER_INVAL
	verifying pools[0..4], nfilled=4
	pool cf897c43-672f-4951-883f-3ed3f88fd710 found in list result
	pool aa31f356-05df-468e-a8e3-27e74f917047 found in list result
	pool b9033daa-3f64-448e-ab6f-5c8532445718 found in list result
	pool 87742e1b-2370-4207-8455-9875a7f98301 found in list result
	success t4: pools[] exact length
	verifying pools[0..3], nfilled=0
	success t5: pools[] under-sized
	success
	teardown: destroyed pool b9033daa-3f64-448e-ab6f-5c8532445718
	teardown: destroyed pool cf897c43-672f-4951-883f-3ed3f88fd710
	teardown: destroyed pool aa31f356-05df-468e-a8e3-27e74f917047
	teardown: destroyed pool 87742e1b-2370-4207-8455-9875a7f98301
	[       OK ] MGMT4: list-pools with multiple pools in sys
	[ RUN      ] MGMT5: retry MGMT_POOL_{CREATE,DESETROY} upon errors
	Fault injection required for test, skipping...
	[  SKIPPED ] MGMT5: retry MGMT_POOL_{CREATE,DESETROY} upon errors
	[==========] 5 test(s) run.
	[  PASSED  ] 4 test(s).
	[  SKIPPED ] 1 test(s), listed below:
	[  SKIPPED ] MGMT5: retry MGMT_POOL_{CREATE,DESETROY} upon errors
	
	 1 SKIPPED TEST(S)
	
	============ Summary src/tests/suite/daos_test.c
	OK - NO TEST FAILURES
Note:
- The -m option is to start only the management tests.
# <a name="shellscript"></a>Shell script 
The  bash shell script [part1_setting_up_single_node_on_CentOS_7.sh](scripts/part1_setting_up_single_node_on_CentOS_7.sh) does all the steps as described above and is listed below.
```bash
#/bin/bash
# Script verified on DAOS v1.0.1

# Variables used in this script
_user=root

# check if daos packages are on the system
find / | grep "daos[a-z,A-Z,_]*\.tar$" >/dev/null
if [ $? -ne 0 ] ; then
	echo "Cannot find daos_*.tar file(s) on the system"
	exit
fi

# look for the daos tar files on the the system and untar them to /opt/intel
tar -C / -xf $(find / | grep "daos_packages.tar" | head -1)
tar -C / -xf $(find / | grep "daos_source.tar" | head -1)
tar -C / -xf $(find / | grep "daos_debug.tar" | head -1)
cp /opt/intel/daos_rpms/packages/daos_packages.repo /etc/yum.repos.d
cp /opt/intel/daos_rpms/packages/daos_source.repo /etc/yum.repos.d
cp /opt/intel/daos_rpms/packages/daos_debug.repo /etc/yum.repos.d

# install epel
yum -y install epel-release

# install daos, daos-client, daos-server
yum -y install daos-client daos-server

# install daos-tests package
yum -y install daos-tests

# Setup Non Persistent Default Runtime Directory, only useful when daos is started after this script without rebooting
mkdir -p /var/run/daos_server
chmod 0755 /var/run/daos_server
chown $_user:$_user /var/run/daos_server

mkdir -p /var/run/daos_agent
chmod 0755 /var/run/daos_agent
chown $_user:$_user /var/run/daos_agent

# Setup Persistent Default Runtime Directory
cat <<-EOF > /etc/tmpfiles.d/daosfiles.conf
  d /var/run/daos_server 0755 $_user $_user - 
  d /var/run/daos_agent 0755 $_user $_user -
EOF

# copy /etc/daos/daos_server.yml to /etc/daos/daos_server.yml if it does not exist
if [ ! -f /etc/daos/daos_server.yml.original ]; then
	mv /etc/daos/daos_server.yml /etc/daos/daos_server.yml.original
fi

# create /etc/daos_server.yml file
cat <<-EOF > /etc/daos/daos_server.yml
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
    # Storage definitions
    # When scm_class is set to ram, tmpfs will be used to emulate SCM.
    # The size of ram is specified by scm_size in GB units.
    scm_mount: /mnt/daos	# map to -s /mnt/daos
    scm_class: ram
    scm_size: 16
EOF
```

# Next
Now that a DAOS server is running on a single node Storage Class Memory (SCM) and NVMe storage can be additionally added.
This is demonstrated in [Part 2 - Configuring SCM and NVMe](part2_modify_daos_server_yml_to_use_SCM_and_NVMe.md).

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

#!/bin/sh
set -e
# set -x

show_help() {
cat << EOF
Usage: ${0##*/} [-h] [-l] [-d distro]
Generate Devstack enabled image based on the distro.

    -h      display this help end exit
    -l      list available distro names
    -d      select distro (default: centos7-latest)
EOF
}

list_distros() {
cat << EOF
Available distros:
- centos-6
- centos-7
- cirros
- debian-8
- fedora-24
- ubuntu-12.04
- ubuntu-14.04
- ubuntu-16.04
EOF
}

DISTRO="ubuntu-16.04"

while getopts "hld:" opt; do
    case "$opt" in
        h)
            show_help
            exit 0
            ;;
        l)
            list_distros
            exit 0
            ;;
        d)  DISTRO=$OPTARG
            ;;
        '?')
            show_help >&2
            exit 1
            ;;
    esac
done
shift "$((OPTIND-1))" # Shift off the options and optional --.

case "$DISTRO" in
    centos-6)
        BASE_IMG_URL="http://cloud.centos.org/centos/6/images/CentOS-6-x86_64-GenericCloud.qcow2"
        ;;
    centos-7)
        BASE_IMG_URL="http://cloud.centos.org/centos/7/images/CentOS-7-x86_64-GenericCloud.qcow2"
        ;;
    cirros-0.3.4)
        BASE_IMG_URL="http://download.cirros-cloud.net/0.3.4/cirros-0.3.4-x86_64-disk.img"
        ;;
    debian-8)
        BASE_IMG_URL="http://cdimage.debian.org/cdimage/openstack/current/debian-8.5.0-openstack-amd64.qcow2"
        ;;
    fedora-24)
        BASE_IMG_URL="https://download.fedoraproject.org/pub/fedora/linux/releases/24/CloudImages/x86_64/images/Fedora-Cloud-Base-24-1.2.x86_64.qcow2"
        ;;
    ubuntu-12.04)
        BASE_IMG_URL="https://cloud-images.ubuntu.com/releases/precise/release/ubuntu-12.04-server-cloudimg-amd64-disk1.img"
        ;;
    ubuntu-14.04)
        BASE_IMG_URL="https://cloud-images.ubuntu.com/releases/14.04/release/ubuntu-14.04-server-cloudimg-amd64-disk1.img"
        ;;
    ubuntu-16.04)
        BASE_IMG_URL="https://cloud-images.ubuntu.com/releases/16.04/release/ubuntu-16.04-server-cloudimg-amd64-disk1.img"
        ;;
    *)
        echo "ERROR: $distro is an invalid distribution name." >&2
        exit 1
        ;;
esac

SEED="seed.iso"
CONSOLE="file:console.log"
# Uncomment to interact with console
# CONSOLE="telnet:localhost:44444,server,nowait"
BASE_IMG_NAME="$(basename $BASE_IMG_URL)"
OUT_PREFIX="${OUT_PREFIX:-devstack}"
OUT_IMG_NAME="${OUT_PREFIX}-${DISTRO}.qcow2"
MEM=1024
KVM_OPTS="-nographic -enable-kvm -m ${MEM} -serial ${CONSOLE}" 
KVM_OPTS="${KVM_OPTS} -net nic,vlan=10,macaddr=00:01:00:00:08:00,model=virtio -net user,vlan=10,net=192.168.0.250/24"
KVM_OPTS="${KVM_OPTS} -drive file=${OUT_IMG_NAME},if=virtio -drive file=${SEED},if=virtio"
META_DATA_FILE="meta-data"
USER_DATA_FILE="user-data"

if [ ! -f "$META_DATA_FILE" ]; then
    echo "$META_DATA_FILE is missing ... Creating default one with content:"
    cat > "$META_DATA_FILE" <<EOL
## Default meta-data
instance-id: iid-local01
local-hostname: devstack-$DISTRO
EOL
    cat "$META_DATA_FILE"
fi

if [ ! -f "$USER_DATA_FILE" ]; then
    echo "$USER_DATA_FILE is missing ... Creating default one with content:"
    cat > "$USER_DATA_FILE" <<EOL
#cloud-config
# Allow logging in with paswords
ssh_pwauth: True
users:
  - default
  - name: stack
    lock_passwd: False
    sudo: ["ALL=(ALL) NOPASSWD:ALL\nDefaults:stack !requiretty"]
    shell: /bin/bash
runcmd:
  - sleep 10 && shutdown -h now
# vim:syntax=yaml
EOL
    cat "$USER_DATA_FILE"
fi

[ ! -f "$BASE_IMG_NAME" ] && wget "$BASE_IMG_URL"
[ -f "$SEED" ] && rm "$SEED"

genisoimage -quiet -o "$SEED" -V cidata -r -J meta-data user-data
[ -f "$OUT_IMG_NAME" ] && rm -f "$OUT_IMG_NAME"
cp "$BASE_IMG_NAME" "$OUT_IMG_NAME"
qemu-img resize "$OUT_IMG_NAME" +2G
echo "Generaring ${OUT_IMG_NAME} ..."
echo "Watch console on ${CONSOLE} ..."
sudo kvm ${KVM_OPTS}
echo "Done!"

Run build.sh to build an image. By default, you get Ubuntu 16.04 as your default.

Watch the build process with
    tail -f console.log

To test what you got, run:
    sudo kvm -m 256 -net nic -net user,hostfwd=tcp::2222-:22 -drive devstack-ubuntu-16.04.qcow2,if=virtio -nographic

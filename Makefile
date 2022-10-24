SHELL := /bin/bash


demo:
	. notes && demo

disk-image:
	. notes && createISO

initrd:
	# I added the moduls from the net installer of fedora.
	pushd u-root
	u-root \
	    -uinitcmd="/init.elvish" \
	    -files "init.elvish:/init.elvish" \
	    -files "../bootdisk/modules:/lib/modules" \
	    -files "../bootdisk/modprobe.d:/lib/modprobe.d" \
	    -files "../bootdisk/udev:/lib/udev" \
	    -files "/tmp/infraenvid:/infraenvid" \
	    -files "/tmp/token:/token" \
	    -o ../bootdisk/initrd \
	    core ./cmds/boot/pxeboot ./cmds/exp/modprobe ./cmds/assisted-bootloader
	popd

run-vm: initrd
	shell . notes && runSingleDiskUrootVM

run-vm-no-disk: initrd
	shell . notes && runUrootVM



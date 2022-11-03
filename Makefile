SHELL := /bin/bash

IMG = fcos-assisted-bootloader.img 

disk-image: verify-tools-exists initrd generate-ignition validate-ignition
	coreos-installer iso customize \
		--live-karg-append "console=ttyS0" \
		--live-ignition assisted-bootloader.ign  \
		-o $(IMG) \
		fedora-coreos-36.20221001.3.0-live.x86_64.iso
		# download the fedora iso using coreos-installer download -t iso
		# fedora-coreos-36.20221001.3.0-live.x86_64.iso
		# extract minimal iso using coreos-install iso extract minimal-iso
		# fcos-minimal.iso 

initrd:
	# I added the moduls from the net installer of fedora.
	cd ./u-root/ && go build && u-root \
	    -uinitcmd="/init.elvish" \
	    -files "init.elvish:/init.elvish" \
	    -files "../bootdisk/modules:/lib/modules" \
	    -files "../bootdisk/modprobe.d:/lib/modprobe.d" \
	    -files "../bootdisk/udev:/lib/udev" \
	    -files "/tmp/infraenvid:/infraenvid" \
	    -files "/tmp/token:/token" \
	    -o ../bootdisk/initrd \
	    core ./cmds/boot/pxeboot ./cmds/exp/modprobe ./cmds/assisted-bootloader

run-vm: 
	qemu-kvm \
		-m 8G \
		-cpu host \
		-smp sockets=2,cores=2 \
		-machine q35 \
		-nographic \
		-chardev stdio,id=char0,mux=on,logfile=serial-0.log,signal=off \
		-chardev pty,id=char1,mux=on,logfile=serial-1.log,signal=off \
		-serial chardev:char0 -mon chardev=char0 \
		-serial chardev:char1 -mon chardev=char1 \
		-drive if=virtio,file=$(IMG),format=raw,media=disk \
		-netdev user,id=n1 \
		-device virtio-net,netdev=n1 \
		-device virtio-rng-pci \
		-monitor unix:/tmp/urootvm,server,nowait \
		-name assisted-bootloader 


run-vm-initrd:
	qemu-kvm \
		-m 8G \
		-cpu host \
		-smp sockets=2,cores=2 \
		-machine q35 \
		-kernel bootdisk/vmlinuz-5.17.5-300.fc36.x86_64 \
		-initrd bootdisk/initrd \
		-nographic \
		-chardev stdio,id=char0,mux=on,logfile=serial-0.log,signal=off \
		-chardev pty,id=char1,mux=on,logfile=serial-1.log,signal=off \
		-serial chardev:char0 -mon chardev=char0 \
		-serial chardev:char1 -mon chardev=char1 \
		-append "console=ttyS0 rd.debug" \
		-netdev user,id=n1 \
		-device virtio-net,netdev=n1 \
		-device virtio-rng-pci \
		-monitor unix:/tmp/assisted-bootloader-vm,server,nowait \
		-name assisted-bootloader

verify-tools-exists:
	which coreos-installer podman ocm 

validate-ignition:
	podman run -i ignition-validate:latest - < assisted-bootloader.ign

generate-ignition:
	sed -e 's/ABL_SCRIPT/$(shell cat assisted-bootloader-install.sh | base64 -w 0)/;s/REFRESH_TOKEN/$(shell ocm token --refresh)/' \
		assisted-bootloader.ign.in > assisted-bootloader.ign
	$(MAKE) validate-ignition

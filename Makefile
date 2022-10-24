SHELL := /bin/bash

tmpdir := $(shell mktemp -d)
target := bootdisk
disk-image: verify-tools-exists initrd 
	cp -v -r $(target)/CD_root $(tmpdir)/CD_root
	cp -v $(target)/initrd $(tmpdir)/CD_root/isolinux/
	mkisofs -o $(tmpdir)/assisted-bootloader.img \
	    -b isolinux/isolinux.bin \
	    -c isolinux/boot.cat \
	    -no-emul-boot -boot-load-size 4 \
	    -boot-info-table \
	    -V uroot -volset uroot -A uroot \
	    -U -r -T -J \
	    $(tmpdir)/CD_root/
	
	isohybrid $(tmpdir)/assisted-bootloader.img
	# remove the partition, otherwise disk extention fails (in linode)
	sfdisk --delete $(tmpdir)/assisted-bootloader.img 1
	gzip -c $(tmpdir)/assisted-bootloader.img > $(tmpdir)/assisted-bootloader.img.gz
	cp -v $(tmpdir)/assisted-bootloader.img $(target)
	cp -v $(tmpdir)/assisted-bootloader.img.gz $(target)
	echo "All ready in $(tmpdir)"

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

run-vm: disk-image
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
		-drive if=virtio,file=bootdisk/assisted-bootloader.img,format=raw,media=disk \
		-netdev user,id=n1 \
		-device virtio-net,netdev=n1 \
		-device virtio-rng-pci \
		-monitor unix:/tmp/urootvm,server,nowait \
		-name assisted-bootloader 


run-vm-initrd: initrd
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
	which mkisofs isohybrid sfdisk gzip


#!/bin/bash
set -o errexit
set -o pipefail



SRC_ISO=live.iso

function check() {
    echo " - ✅"
}

function extract_disk_from_iso() {
    echo -n "Extracting live metal iso from openshift-install version $(openshift-install version)"
    iso=$(openshift-install coreos print-stream-json \
        | jq -r '.architectures.x86_64.artifacts.metal.formats.iso.disk.location')
    check

    echo -n "Downloading the metal ${iso} to ${SRC_ISO}..."
    #curl -L ${iso} -o ${SRC_ISO}
    check

    echo -n "Customizing kargs..."
    # see https://bugzilla.redhat.com/show_bug.cgi?id=1901401
#    coreos-installer iso customize \
#        --live-karg-append initrd=/images/pxeboot/initrd.img,/images/ignition.img,/images/pxeboot\/rootfs.img \
#        --live-karg-replace ignition.platform.id=metal=openstack \
#        --live-karg-delete coreos.liveiso=$(coreos-installer iso kargs show ${SRC_ISO} | grep -Po '(?<=^coreos.liveiso=#)[^\s]*')  \
#        -o live-customized.iso \
#        ${SRC_ISO}
#    check

    echo -n "Remove the embedded ignition..."
    coreos-installer iso ignition remove live-customized.iso -o live-customized-no-ignition.iso
    check

    echo -n "Remove the ISO partition (to pass validation in assisted service)..."
    #sfdisk --delete live-customized.iso 1
    check

    echo -n "Convert the iso to a qcow2 disk..."
    qemu-img convert -O qcow2 live-customized-no-ignition.iso live-customized.qcow2
    check
}

function extract_ignition() {
    echo -n "Download ignition from a target infra env"
    curl -s \
        -H "Authorization: Bearer $(ocm token)" \
         "https://api.openshift.com/api/assisted-install/v2/infra-envs" \
         | jq '.[]|{name,cluster_id, infraenv_id:.id}'

    read -p "infra env id: " -a infra_env_id

    echo -n "Downloading infra-env's ignition to ignition.ign"
    curl -s \
        -H "Authorization: Bearer $(ocm token)" \
         "https://api.openshift.com/api/assisted-install/v2/infra-envs/${infra_env_id}/downloads/files-presigned?file_name=discovery.ign" \
         | jq  -r '.url' | curl $(cat /dev/stdin) -o ignition.ign
    check
}

function extract_iso_files() {
    echo extract files
    echo xorriso -osirrox on -dev $1 -extract  /isolinux/isolinux.cfg isolinux.cfg
    echo add files
    echo xorriso  -dev $1 -outdev live3.iso -map isolinux.cfg /isolinux/isolinux.cfg
    echo rm files
    echo xorriso -dev $1 -rm isolinux.cfg
}


#!/bin/bash

centos=CentOS-7-x86_64-GenericCloud-1710
fedora=Fedora-Cloud-Base-27-1.6.x86_64
centos_ext=raw.tar.gz
fedora_ext=raw.xz
centos_url=https://cloud.centos.org/centos/7/images/$centos.$centos_ext
fedora_url=https://download.fedoraproject.org/pub/fedora/linux/releases/27/CloudImages/x86_64/images/$fedora.$fedora_ext
sata=hardcore

for os in centos fedora; do
    vm=${!os}
    eval os_url=\$$os\_url
    eval os_ext=\$$os\_ext

    echo create $vm-cidata.iso
    cp meta-data-$os meta-data
    rm -rf $vm-cidata.iso
    mkisofs -output $vm-cidata.iso -volid cidata -joliet -rock user-data meta-data 2> /dev/null
    rm -rf meta-data
    if ! ls $vm*.raw 1> /dev/null 2>&1; then
        echo wget -c $os_url; echo
        wget -c $os_url
        echo extract $vm.$os_ext
        echo $vm.$os_ext | grep -iq centos && pv $centos.$centos_ext | tar xzf - || xz -dv $vm.$fedora_ext
    fi

    if [ ! -f $vm.vdi ]; then
        echo $vm | grep -qi "fedora" && logo=Fedora_64 || logo=RedHat_64

        echo;echo convertfromraw; echo

        VBoxManage convertfromraw --format VDI $vm.raw $vm.vdi 2> /dev/null
        VBoxManage modifyhd --resize 100000 $vm.vdi 2> /dev/null

        echo createvm $vm; echo

        VBoxManage createvm --name "$vm" --ostype $logo --register 2> /dev/null
        VBoxManage modifyvm $vm --nic1 bridged --bridgeadapter1 en0 --cpus 4 --memory 4096 --chipset ich9
        VBoxManage storagectl $vm --name "$sata" --add sata --portcount 1
        VBoxManage storageattach $vm --storagectl "$sata" --port 0 --device 0 --type hdd --medium $vm.vdi
        VBoxManage storageattach $vm --storagectl "$sata" --port 1 --device 0 --type dvddrive --medium $vm-cidata.iso
        VBoxManage snapshot $vm take $vm-deployed
        VBoxHeadless --startvm $vm &
    fi
done

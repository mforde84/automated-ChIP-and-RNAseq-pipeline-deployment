#!/bin/bash

flav=$(cat ~/env/flav)
diskspace=$(cat ~/env/diskspace)
img=$(nova image-list | grep "forde_base_xorg_butterfly" | awk ' { print $2 } ');
echo "Launching VM"
nova boot --flavor "$flav" --image "$img" mike-align-vm
echo "Waiting 5min for VM to come online"
sleep 300

export vm="$(nova list | grep 'mike-align-vm' | awk ' { print $2 } ')"
export hole="$(nova list | grep 'mike-align-vm' | awk ' { print $12 } ')"
export ip="$(echo $hole | sed 's/private=//g')"

echo "Transfer needed files"
eval $(ssh-agent)
scp -i ~/.ssh/mf-half.pem ~/inject.tar.gz ubuntu@"$ip":~
scp -i ~/.ssh/mf-half.pem ~/env/* ubuntu@"$ip":~

echo "Attach volumes to VM"
nova volume-create --display-name mike-align-temp "$diskspace"
vol="$(nova volume-list | grep 'mike-align-temp' | awk ' { print $2 } ')"
nova volume-attach "$vm" "$vol" /dev/vdc

ssh -i ~/.ssh/mf-half.pem ubuntu@"$ip" './p_v4.sh' && ./clean_v4.sh

exit 0

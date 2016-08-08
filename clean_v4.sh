#!/bin/bash

source .novarc
vm="$(nova list | grep 'mike-align-vm' | awk ' { print $2 } ')"
vol="$(nova volume-list | grep 'mike-align-temp' | awk ' { print $2 } ')"
nova volume-detach "$vm" "$vol"
wait 300
cinder delete "$vol"
nova delete "$vm"
kill -9 `ps -ef | grep "mbolt" | grep "ssh-agent" | awk ' { print $2 } '`

exit 0


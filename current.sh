#!/bin/bash
exec 2>/dev/null
mem=0;
disk=0;
eph=0;
swap=0;
cpu=0; 
for i in $(nova list | awk ' { print $2 } '); do  
	if [ "$i" != "ID" ]; then  
		export flav="| "$(nova show "$i" | grep "flavor" | awk ' { print $5 } ' | sed 's/(//g' | sed 's/)//g')" |"; 
		let mem=$(($(nova flavor-list | grep "$flav" | awk '{print $6}') + $mem)); 
		let disk=$(($(nova flavor-list | grep "$flav" | awk '{print $8}') + $disk)); 
		let eph=$(($(nova flavor-list | grep "$flav" | awk '{print $10}') + $eph)); 
		if [ $(nova flavor-list | grep "$flav" | awk '{print $12}') != "|" ]; then 
			let swap=$(($(nova flavor-list | grep "$flav" | awk '{print $12}') + $swap)); 
			let cpu=$(($(nova flavor-list | grep "$flav" | awk '{print $14}') + $cpu)); 
		else 
			let swap=$(($swap + 0)); 
			let cpu=$(($(nova flavor-list | grep "$flav" | awk '{print $13}') + $cpu)); 
		fi; 
	fi; 
done; 
echo "mem = "$mem", disk = "$disk", eph = "$eph", swap = "$swap", cpu = "$cpu;
exit 0;

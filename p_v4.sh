#!/bin/bash

echo "Set general env vars"
source ~/.novarc
sudo sh -c "echo 'kernel.shmmax = 31000000000' >> /etc/sysctl.conf"
sudo sh -c "echo 'kernel.shmall = 31000000000' >> /etc/sysctl.conf"
sudo /sbin/sysctl -p
export threads=$(grep -c ^processor /proc/cpuinfo)
export DATE=`date +%Y-%m-%d-%H-%M-%S`
export http_proxy="http://cloud-proxy:3128"
export https_proxy="http://cloud-proxy:3128"

echo "Extract injection archive and set run env vars"
tar -xvzf inject.tar.gz
mv html-key ~/.ssh
export imin="$(cat ~/imin)"
export imax="$(cat ~/imax)"
export multi="$(cat ~/multi)"
export sjmin="$(cat ~/sjmin)"
export sjdbmin="$(cat ~/sjdbmin)"
export librarynum="$(cat ~/libnum)"
export librarynames=$(cat ~/libname)
export inputnum="$(cat ~/inputcount)"
export inputassoc=$(cat ~/inputassoc)
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/home/ubuntu/bamtools/lib

echo "Download additional software"
sudo apt-get update && sudo apt-get install bedtools samtools build-essential cmake fastqc default-jdk default-jre cython xfsprogs -y
git clone https://github.com/pezmaster31/bamtools
mkdir bamtools/build
cd bamtools/build
cmake ..
make
cd
sudo pip install numpy
git clone https://github.com/taoliu/MACS
cd MACS
sudo python setup_w_cython.py install
sudo cp bin/macs2 /usr/bin
cd

echo "Put precompiled binaries in path"
sudo mv STAR /usr/bin
sudo mv fast_count /usr/bin
sudo mv bedClip /usr/bin
sudo mv bedGraphToBigWig /usr/bin
sudo mv bedSort /usr/bin
sudo mv wigCorrelate /usr/bin

echo "Format and mount cinderblock to VM"
unset http_proxy
unset https_proxy
sudo mkfs.xfs /dev/vdc
sudo mount /dev/vdc /mnt
sudo chown -R ubuntu:ubuntu /mnt

echo "Download references to cinderbloack"
mkdir /mnt/references
cd /mnt/references
swift download mike_hg19_refs
sudo dd if=/dev/zero of=swapfile bs=1G count=32
sudo chmod 600 swapfile
sudo mkswap /mnt/references/swapfile
sudo swapon /mnt/references/swapfile

echo "Downloading raw sequencing files to cinderblock"
mkdir /mnt/workspace
COUNT=1
cd /mnt/workspace
while [ $COUNT -le $librarynum ]; do
 current_lib="$(echo $librarynames | awk -v c=$COUNT '{ print $c }')/"
 for f in $(swift list FTWFMLWGS | grep "$current_lib"); do
  swift download FTWFMLWGS $f
 done
 let COUNT=COUNT+1
done

echo "Create chip/input lookup table"
cd
COUNT=1
while [ $COUNT -le $inputnum ]; do
 first_lib="$(echo $inputassoc | awk -v c=$COUNT '{ print $c }' | awk -F"," '{ print $1 }')/"
 second_lib="$(echo $inputassoc | awk -v c=$COUNT '{ print $c }' | awk -F"," '{ print $2 }')/"
 for f in $(swift list FTWFMLWGS | grep "$first_lib" | grep "_1_sequence"); do
  echo -ne "\n/mnt/workspace/$f.Aligned.out.bam.sort.bam~~~" >> macs2.lookup
  for x in $(swift list FTWFMLWGS | grep "$second_lib" | grep "_1_sequence"); do
   echo -ne "/mnt/workspace/$x.Aligned.out.bam.sort.bam " >> macs2.lookup
  done
  echo -ne "~~~$(echo $inputassoc | awk -v c=$COUNT '{ print $c }' | sed 's/,/vs/g' | sed 's/ /-/g')" >> macs2.lookup
 done
let COUNT=COUNT+1
done

echo "Create analyses directory"
mkdir -p /mnt/analyses/chip
mkdir /mnt/analyses/bam
mkdir /mnt/analyses/log
mkdir /mnt/analyses/fastqc
mkdir /mnt/analyses/count
mkdir /mnt/analyses/chip/wiggle 

while read -rd $'\0' f; do
 file_replace="$(echo $f | sed 's/_1_sequence/_2_sequence/g')"
 echo "Starting alignment for $f"
 STAR --runMode alignReads --readFilesCommand zcat --outFileNamePrefix "$f". --runThreadN $threads --genomeLoad=LoadAndKeep --genomeDir /mnt/references/REFS/GENCODE19/Genome --readFilesIn "$f" "$file_replace" --outSAMtype BAM Unsorted --outFilterType BySJout --outFilterMultimapNmax $multi  --alignSJoverhangMin $sjmin --alignSJDBoverhangMin $sjdbmin --outFilterMismatchNmax 8 --alignIntronMin $imin --alignIntronMax $imax  --alignMatesGapMax 1000000
 echo "Sorting $f"
 samtools sort -@ $threads "$f.Aligned.out.bam" "$f.Aligned.out.bam.sort"
 cp "$f.Aligned.out.bam.sort.bam" /mnt/analyses/bam/
 mv "$f".Log.final.out /mnt/analyses/log/
done < <(find /mnt -name "*_1_sequence*.txt.gz" -print0)
STAR --genomeLoad=Remove --genomeDir /mnt/references/REFS/GENCODE19/Genome 

echo "QC"
find /mnt -name "*.sort.bam" | xargs -n 1 -P $threads -iFILES sh -c 'fastqc -t 1 -o /mnt/analyses/fastqc/ --extract -f bam FILES'

echo "Performing counts"
todo=$(find /mnt -name '*sort.bam')
annotation="$(cat ~/gtf.location)"
fast_count "$threads" "$annotation" $todo > /mnt/analyses/count/count_"$DATE".txt

if [[ -s ~/macs2.lookup ]]; then
 cat ~/macs2.lookup | xargs -n 1 -P 8 -L 1 -iLINES sh -c 'export hold="LINES"; chipfile=$(echo $hold | awk -F "~~~" '\''{print $1}'\''); controlfile=$(echo $hold | awk -F"~~~" '\''{print $2}'\''); export chip_name=$(echo $hold | awk -F"~~~" '\''{print $3}'\''); export insert=$(samtools view $chipfile | head -n 1000 | python ~/insertsize.py - | tail -n 1 | sed "s/,//g" | awk '\''{print int($4+0.5)}'\''); export shift=$((insert / 2)); macs2 callpeak -t $chipfile -c $controlfile -B --nomodel --shift $shift --SPMR -g hs -q 0.01 --broad -f BAMPE -n "$chipfile"_"$chip_name".macs2' 
 for f in $(find /mnt -name "*macs*"); do
  cp $f /mnt/analyses/chip/
 done
 cat ~/macs2.lookup | xargs -n 1 -P 8 -L 1 -iLINES sh -c 'export hold="LINES"; chipfile=$(echo $hold | awk -F "~~~" '\''{print $1}'\''); export chip_name=$(echo $hold | awk -F"~~~" '\''{print $3}'\''); macs2 bdgcmp -t "$chipfile"_"$chip_name".macs2_treat_pileup.bdg -c "$chipfile"_"$chip_name".macs2_control_lambda.bdg -o "$chipfile"_"$chip_name".macs2.FE.bdg -m FE' 
 cat ~/macs2.lookup | xargs -n 1 -P 8 -L 1 -iLINES sh -c 'export hold="LINES"; chipfile=$(echo $hold | awk -F "~~~" '\''{print $1}'\''); export chip_name=$(echo $hold | awk -F"~~~" '\''{print $3}'\''); macs2 bdgcmp -t "$chipfile"_"$chip_name".macs2_treat_pileup.bdg -c "$chipfile"_"$chip_name".macs2_control_lambda.bdg -o "$chipfile"_"$chip_name".macs2.logLR.bdg -m logLR -p 0.00001'
 find /mnt -name "*macs2.FE.bdg" | xargs -n 1 -P $threads -iFILES sh -c 'bedSort FILES FILES.sort.bdg; bash ~/bdg2bw FILES.sort.bdg ~/chromInfo.txt; cp FILES.sort.bdg /mnt/analyses/chip/; cp FILES.sort.bdg.bw /mnt/analyses/chip/wiggle/'
 find /mnt -name "*macs2.logLR.bdg" | xargs -n 1 -P $threads -iFILES sh -c 'bedSort FILES FILES.sort.bdg; bash ~/bdg2bw FILES.sort.bdg ~/chromInfo.txt; cp FILES.sort.bdg /mnt/analyses/chip/; cp FILES.sort.bdg.bw /mnt/analyses/chip/wiggle/;'
fi

echo "Upload to object store"
for f in *; do
 swift upload mike_analyses -S 1073741824 "$f"
done

export http_proxy="http://cloud-proxy:3128"
export https_proxy="http://cloud-proxy:3128"
echo "Upload to server"
cd /mnt/analyses
for f in *; do
 scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -r -i ~/.ssh/html-key "$f" blik@128.135.219.177:/var/www/html
done

exit 0

#!/bin/bash

source .novarc

nova flavor-list
echo "which flavor?"
read flav
echo $flav > ~/env/flav
echo "How much diskspace (Gb)?"
read diskspace
echo $diskspace > ~/env/diskspace
swift list FTWFMLWGS
echo "How many libraries do you want to analyze?"
read librarynum
echo $librarynum > ~/env/libnum
echo "What are the library names? (e.g., 2015-85 2015-213)"
read librarynames
echo $librarynames > ~/env/libname
echo "Is this enhancerseq? (y or n)"
read flag
if [ "$flag" = "y" ]; then
    echo "/home/ubuntu/hg19-liftover.gtf" > ~/env/gtf.location
    echo "1" > ~/env/multi
    echo "50" > ~/env/sjmin
    echo "50" > ~/env/sjdbmin
    echo "50" > ~/env/imin
    echo "1" > ~/env/imax

else
    echo "/home/ubuntu/genes.gtf" > ~/env/gtf.location
    echo "20" > ~/env/multi
    echo "8" > ~/env/sjmin
    echo "1" > ~/env/sjdbmin
    echo "20" > ~/env/imin
    echo "1000000" > ~/env/imax
fi
echo "Do you want to peak call? (y or n)"
read peakfilter
if [ "$peakfilter" = "y" ]; then
    echo "How many are chip / input library sets do you have?"
    read controlcount
    echo $controlcount > ~/env/inputcount
    echo "Please indicate chip / input assocations (e.g., 2015-85,2015-86 2015-111,2015-99):"
    read controlsfilter
    echo $controlsfilter > ~/env/inputassoc
fi

nohup ./run_v4.sh > nohup.out &

clear
echo "Job is running in background"
echo "Once completed the files will be available for download from http://128.135.219.177"
echo "Type progress to show progress"
echo "Type resources to see resource utilization"
echo "Type files to see workspace"

exit 0

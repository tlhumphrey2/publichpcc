#!/bin/bash
# USE THIS SCRIPT when volume is attached for the 1st time AND we want it to be formated and mounted on $mountpoint
volume=$1
mountpoint=$2
# Construct XFS filesystem on $volume 
echo "mkfs.xfs $volume"
mkfs.xfs $volume 

#----------------------------------------------------------------
echo "mount $volume /mnt"
mount $volume /mnt

#----------------------------------------------------------------
echo "mount -o remount -o noatime /mnt/"
mount -o remount -o noatime /mnt/

#----------------------------------------------------------------
echo "mount $volume $mountpoint"
mount $volume $mountpoint

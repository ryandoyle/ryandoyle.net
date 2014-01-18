---
layout: post
title:  "Expanding a LVM partition to fill remaining drive space"
date:   2009-12-08 23:08:01
comments: true
---

When I deploy new servers through VMWare ESX, I usually copy an existing base that I have already setup. I keep the base image VMDK size small so it is quick to copy. When I have copied the image and am setting up a new server, I adjust the size of the VMDK in VMWare and then use gparted to fill up the space that is added to the end of the virtual disk.

This works fine for normal partitions, but as I found out today, gparted doesn’t play so nicely with LVM. Anyway, to cut a long story short, these are the commands that I had to use to fill up the remaining space of the root partition. I could have created a new partition and then added this to the volume group, but I wanted to keep things clean. After all, LVM is supposed to make things easier.

Ill assume that you want to grow your root partition. Ill also assume that you have a basic LVM structure like the default CentOS 5 partitioning layout. Also, make sure you have a backup of the data on the partitions you will be messing with. When doing these kind of operations, it is very easy for data loss to happen. I did this and it worked for me but I can’t garuntee that it will for you. The main thing to watch out for is the partitioning layout I am using in this example.

    /dev/sda1 = /boot
    /dev/sda2 = VolGroup00
    /dev/VolGroup00/LogVol00 = /
    /dev/VolGroup00/LogVol01 = swap

First increase the size of your VMDK through the appropriate tool. I use VI Client to do this for ESX. Its a bit different for VMWare Workstation and VMWare Server. Then go through these commands:

    [root@linux~]# fdisk /dev/sda

    The number of cylinders for this disk is set to 5221.
    There is nothing wrong with that, but this is larger than 1024,
    and could in certain setups cause problems with:

    1) software that runs at boot time (e.g., old versions of LILO)
    2) booting and partitioning software from other OSs
    (e.g., DOS FDISK, OS/2 FDISK)

    Command (m for help):

We now need to delete the sda2 partition and re-add it. When we re-add it, we can change the number of cylinders to fill the partition up with all the remaining space. Press p to print the current partitions.

    Command (m for help): p

    Disk /dev/sda: 42.9 GB, 42949672960 bytes
    255 heads, 63 sectors/track, 5221 cylinders
    Units = cylinders of 16065 * 512 = 8225280 bytes

    Device Boot      Start         End      Blocks   Id  System
    /dev/sda1   *           1          13      104391   83  Linux
    /dev/sda2              14        5221    41833260   8e  Linux LVM

    Command (m for help):

We want to delete partition 2 and re-add it again so we can fill up the remaining space. Press d and then select partition 2.

    Command (m for help): d
    Partition number (1-4): 2

    Command (m for help):

Now we will re-create the partition. Set the partition number to 2, for the starting cylinder, set to whatever was the starting cylinder before. The default should be set as this anyway. For the end cylinder, leave the default as this will have the value of the last available cylinder.

    Command (m for help): n
    Command action
    e   extended
    p   primary partition (1-4)
    p
    Partition number (1-4): 2
    First cylinder (14-5221, default 14):
    Using default value 14
    Last cylinder or +size or +sizeM or +sizeK (14-5221, default 5221):
    Using default value 5221

    Command (m for help):

Finally we want to change the type to LVM (8E)

    Command (m for help): t
    Partition number (1-4): 2
    Hex code (type L to list codes): 8e
    Changed system type of partition 2 to 8e (Linux LVM)

    Command (m for help):

Save and quit with w

    Command (m for help): w

You will now need to reboot. After the reboot we use the pvresize command to fill out the extra space. As fair as I can tell, this resizes the amount of space that a LVM volume group can use on a partition and needs to be run if you resize its partition.

    pvresize /dev/sda2

Now we need to resize the logical volume, LogVol00. We use lvresize for this. There is a funny looking argument that is passed to resize. We don’t say that we want to fill the rest of the volume, we say that we want to add 100% of the free space to the volume.

    lvresize -l +100%FREE /dev/VolGroup00/LogVol00

Finally we want to resize the actual underlying file system. I am using ext3 for the root so I use the resize2fs command

    resize2fs /dev/VolGroup00/LogVol00

There is no reboot needed after this. Do a df and see the results!
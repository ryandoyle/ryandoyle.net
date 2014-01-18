---
layout: post
title:  "Replace failed drive in Linux software RAID1"
date:   2008-10-08 16:05:01
comments: true
---

I recently had to replace a failed drive in my Linux server (in fact, the server that this blog is hosted). It is setup as 2 x 200GB PATA hard drives configured in Linux software RAID1.

Once you have identified that the RAID has failed (you will get an email about the event if you have set your server up properly), make sure you have a disk of equal of greater size. I only had a spare 250GB HDD spare, so I used that.

The following commands assume that hdc was the failed drive and that hda is the drive that is still working

    sfdisk -d /dev/hda | sfdisk /dev/hdc
    mdadm /dev/md0 -a /dev/hdc1
    mdadm /dev/md1 -a /dev/hdc2
    mdadm /dev/md2 -a /dev/hdc3

I have 3 partitions, md0 is the boot partition, md1 is swap and md2 is my root partition. Modify your configuration to suit. You can then view the rebuilding by executing

    watch -n .5 ‘cat /proc/mdstat’

You will also want to copy over the boot record so you will be able to boot the server from hdc incase hda fails next. Pretty much every linux uses grub now so I will show how to use that.

    grub
    grub> root (hd1,0)
    grub> setup (hd1)
    grub> quit

And that should be it. That is what I did on my system and it worked fine. That said I don’t take any responsibility for breaking your RAID :)
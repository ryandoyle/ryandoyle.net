---
layout: post
title:  "Western Digital MyBook World and mounting CIFS"
date:   2008-10-18 01:09:01
comments: true
---

Background
----------

I bought a [500GB WD MyBook World](http://www.wdc.com/en/products/Products.asp?DriveID=278) edition with the intention of using it to backup various servers on my network. I did a bit of research and found out that it ran Linux and also had a pretty decent community following; [here](http://martin.hinner.info/mybook/) and [here](http://mybookworld.wikidot.com/). It isn’t anywhere near what the NSLU2 had (I was planning to purchase an NSLU2 and found out they were no longer in production) but it was still enough to convince me of my purchase. The plan was to mount the servers file systems locally on the MyBook and then use rsnapshot to take snapshots. The MyBook would sit in my cupboard doing its thing each night backing up files.

After purchasing the box it was pretty quick to enable SSH. I hit a brick wall when I tried to compile the CIFS module on the MyBook. It only had GCC 3.4 and the kernel was compiled with GCC 4.1 which would mean the strings wouldn’t match and wouldn’t load itself in. After many, many frustrating hours setting up a cross compiling ARM toolchain on my laptop, I managed to compile the module and eventually loaded it into the kernel.

Doing it yourself
-----------------

SSH into the MyBook and issue the following commands.

    wget http://files.doylenet.net/linux/mybook/modules/2.6.17.14/cifs.ko

Make the directory for CIFS and copy it accross

    mkdir /lib/modules/2.6.17.14/kernel/fs/cifs
    cp cifs.ko /lib/modules/2.6.17.14/kernel/fs/cifs/

Now we would normally use depmod to add the module to the modules.dep file and find any dependancies that module requires, but the MyBook doesn’t have it installed and I couldn’t be bothered compiling it, so we can add the line that is required manually. Don’t forget the double “>”’s!!! I cannot stress this enough. If you don’t use >> then the entire file will get overwritten and you will brick your MyBook!

    echo "/lib/modules/2.6.17.14/kernel/fs/cifs/cifs.ko:" >> \
    /lib/modules/2.6.17.14/modules.dep

Now use modprobe to load the module into the kernel

    modprobe cifs

Finally we mount the CIFS share using the mount.cifs program (its part of samba). Add /usr/local/samba/sbin into your PATH if you want to use the “mount -f cifs” style, but the way shown below works fine.

    /usr/local/samba/sbin/mount.cifs //server/share /mnt \
      -o username=someuser,password=somepass

That should be it! Remember to pass the ro (read only) option if you are using this for backup purposes. And remember, I take NO responsibility if you brick your MyBook. This worked for my 500GB MyBook World. I assume it will work for other models but won’t guarantee anything.

Conclusion
----------

It was painful getting this module to compile so it would load cleanly into the kernel. I had a lot of trouble with buildroot (what the MyBook is based off) but eventually found a version that compiled for me. Ill blog a bit later on getting NFS mounted onto the MyBook as well. I’ve got the module ready but I am having a couple of issues getting nfs-utils to compile.

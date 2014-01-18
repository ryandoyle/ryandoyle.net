---
layout: post
title:  "Extended ACLs with Samba 3 in a 2K3 environment"
date:   2007-12-20 08:34:01
comments: true
---

There are a few documents around dealing with extended ACL support in Linux and Samba, but little documentation about its current implementation. The solution I came up with allows for domain admins to have the same level of control on files and directories as the root user and set permissions as one would on a 2003 server with NTFS permissions.

First, I am going to assume that you have Samba authenticating off a Windows 2000/2003 domain using Winbind. If you haven’t set this up, there are numerous documents around that deal with this. I will write another post at a later date on how to do this when I get the time. Also, I will assume that you are using the latest Samba RPM as it should contain support for extended ACLs. The third assumption is that you are using ext3 and that ACL support is enabled in the kernel. CentOS 5 has all of this enabled, so I will be using this as a base.

First, lets enable ACL support on our file system that will host out Samba shares. Open up /etc/fstab and change the line below

    /dev/sda1 / ext3 defaults 1 1

to:

    /dev/sda1 / ext3 rw,acl 1 1

Now we need to remount the root file system by issuing the following command

    mount -v -o remount /

This may take a few minutes. It took about 3-4 for myself. Once this is complete, we will edit our smb.conf file to include the following [global] configuration options

    [global]
    ....
    map acl inherit = yes
    nt acl support = yes
    ....

This allow extended ACLs to be applied to the file system. Now we need to allow domain admins permission to change ACLs on the files contained within the shares. Because Linux/UNIX only allows the owner or root to change the permissions of a file, we use the “admin users” option on the share to overwrite this. Edit the smb.conf file to include the following on the selected share.

    [sharename]
    path = /home/share
    ....
    admin users = @"DOMAIN\Domain Admins"

Restart samba and now try accessing the share from a Windows machine. Check the security tab and add a user in just for kicks. Apply and close the properties window. Now open it again to make sure that the security was retained. If everything was setup correctly, the user you added permission to should still be there. It should look something like below.

![1](/assets/posts/extendedacls1.jpg)

We can also check our Samba server file system permissions using the getfacl tool. This is what it look like if we execute it on the share that we set the permissions on before.

![1](/assets/posts/extendedacls2.jpg)

Here we can see that there are both the normal UNIX permissions (displayed up the top of the window, on each line starting with #) and the extended permissions.

### Conclusion
Extended ACLs aleviate a lot of permissions headaches when working with Samba in a Windows domain environment. It saves having to continuously chown files that get re-owned by root when you do ceartain functions on them. Also, some files are required to be owned by root (such as VMware virtual machine configuration files), and adding extended ACLs means that we can still copy and manage these VM files without having to chown them to move the files and then chown them back one they are copied accross.

### Referrences
[http://c.mills.ctru.auckland.ac.nz/Samba/XfsAclWinAuth.html](http://c.mills.ctru.auckland.ac.nz/Samba/XfsAclWinAuth.html)

[http://articles.techrepublic.com.com/5100-10878_11-6091748.html](http://articles.techrepublic.com.com/5100-10878_11-6091748.html)




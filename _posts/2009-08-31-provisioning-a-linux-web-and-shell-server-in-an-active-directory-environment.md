---
layout: post
title:  "Provisioning a Linux web and shell server in an Active Directory environment"
date:   2009-08-31 01:55:01
comments: true
---

In this rather large tutorial, I will go over setting up a Linux server to be used for user web space, shell access, FTP access any anything else that is PAM aware. All user accounts will reside in Active Directory. There is no password synchronisation or dirty scripts to pull it all together.

Overview
--------

This tutorial is based on the setup that I deployed recently at my work. We were wanting to give students web space but didn’t want to use IIS and also didn’t want to manually manage user accounts on a Linux server. I have used Samba/Winbind to join other web servers to our domain so that administrators can edit websites through SMB/CIFS instead of using FTP which had worked fine. This guide is basically an extension of that.

This guide will follow these steps listed below:

- Step 1: Setup NTP to syncronise time
- Step 2: Setup Kerberos
- Step 3: Setup Samba
- Step 4: Join the server to the domain
- Step 5: Edit the nsswitch file
- Step 6: Edit the fstab
- Step 7: Add pam_winbind PAM module
- Step 8: Edit the user skeleton directory
- Step 9: Add the pam_mkhomedir module
- Step 10: Setup Apache
- Step 11: Setup vsftpd
- Step 12: Optional: Setup quotas
- Step 13: Optional: Setup IPTables
- Step 14: Optional: Setup sudo

Quota’s, IPTables and sudo are optional steps but I recommend that you at least read over why you might want them.

In the end you will have a server that does the following:

- Users will be able to login using SSH with their Active Directory credentials
- Users will be able to upload files to their website using FTP with their Active Directory credentials
- Users will be able to upload files to their website through SMB/CIFS. If they are already logged onto the domain, they will not need to login again to access this.
- Users’ home directories will be automatically created
- Depending upon their AD group, users will have quotas automatically assigned.
- Depending upon their AD group, users may or may not be able to access the Internet whilst using their shell
- Depending upon their AD group, users will be able to sudo (useful for domain admins group to be able to sudo, as they don’t need to know the root password of the box)
- And more! Anything that is PAM aware will be able to use AD credentials.

Step 0: Base CentOS 5 Install
-----------------------------

This tutorial will be using CentOS. Why? Because it is stable, mature and pretty well supported. <strike>For servers, I run nothing else</strike> (Ahh, I was so naive in my younger years!). We will also make a few assumptions regarding the setup:

- Your domain is known as example.com
- The short name/NT name of your domain is EXAMPLE
- The host name for this server will be webs, with an IP of 10.0.0.50
- Your have 2 domain controllers, with names dc1 and dc2. IP’s are 10.0.0.10 and 10.0.0.20
- Your server has just one partition, the root partition. (This is only relevant for quota support)


Setup CentOS 5 on a server using as small a footprint as possible. You don’t need X or any of the development stuff. We will install the bits and pieces that you will need using yum along the way. I will assume that you have networking setup and **your DNS servers are your DNS servers for your domain** (usually your domain controller/s).

**file: /etc/resolv.conf**

    search example.com
    nameserver 10.0.0.10
    nameserver 10.0.0.20

Also be sure to edit your hosts file and make sure this server name is listed in it.

**file: /etc/hosts**

    127.0.0.1   localhost.localdomain localhost
    ::1         localhost6.localdomain localhost6
    10.0.0.50   webs.example.com webs

Step 1: Setup NTP client
------------------------

Install NTP using yum

    # yum install ntp

Now ideally you would synchronise the time by editing the /etc/ntp.conf file and adding your domain controllers in as NTP servers. I have tried this a few times but I always end up with the clock out. It is very important to keep the clock in sync. If you have a **clock skew of more than 5 minutes from your domain, you will loose authentication completely**. I do something that isn’t ideal but it works. I set the ntpclient to syncronise the time every 5 minutes using cron. I have read that this is not recommended as the sudden change in time can upset things, but I have only read this and I haven’t come across any issues as of yet. If you choose to go down my route, add the following into your /etc/crontab.

**file: /etc/crontab**

    */5 * * * * root /usr/sbin/ntpdate -s dc1.example.com

Step 2: Setup Kerberos
----------------------

Kerberos is an authentication scheme originally created at MIT. Windows 2000/2003/2008 domains use Kerberos and we need to set it up on the Linux server to be able to join it to AD. Edit your /etc/krb5.conf file to contain the following:

**file: /etc/krb5.conf**

    [logging]
     default = FILE:/var/log/krb5libs.log
     kdc = FILE:/var/log/krb5kdc.log
     admin_server = FILE:/var/log/kadmind.log

    [libdefaults]
     default_realm = EXAMPLE.COM
     dns_lookup_realm = false
     dns_lookup_kdc = false

    [realms]
     EXAMPLE.COM = {
      kdc = dc1.example.com:88
      kdc = dc2.example.com:88
      default_domain = example.com }

    [domain_realm]
     .example.com = EXAMPLE.COM
     example.com = EXAMPLE.COM

    [kdc]
     profile = /var/kerberos/krb5kdc/kdc.conf

    [appdefaults]
     pam = {
       debug = false
       ticket_lifetime = 36000
       renew_lifetime = 36000
       forwardable = true
       krb4_convert = false
     }

If you only have one domain controller, don’t add in the line for the second one. That is it for Kerberos.

Step 3: Setup Samba
-------------------

Samba is awesome. Winbind (part of samba) will be doing all the hard work to provide authentication details to SSH, FTP etc… from AD. Before we do anything though, we need to install it.

    # yum install samba

It is a fairly large download, about 25MB. Once it has finished downloading and installing, move the example configuration file it comes with.

    # mv /etc/samba/smb.conf /etc/samba/smb.conf.example

Now create /etc/samba/smb.conf and add the following contents, editing the parts that are suitable.

**file: /etc/samba/smb.conf**

    [global]
    # General name options
    workgroup               = EXAMPLE
    netbios name            = webs

    server string           =

    idmap uid               = 10000-20000
    idmap gid               = 10000-20000

    security                = ads
    encrypt passwords       = yes

    realm                   = example.com
    password server         = dc1.example.com
    os level                = 10
    # Winbind Stuff - Active Directory
    winbind enum users      = yes
    winbind enum groups     = yes
    winbind nested groups   = yes
    winbind use default domain      = yes
    template shell          = /bin/bash
    template homedir        = /home/%D/%U
    obey pam restrictions   = yes

    # Disabled printing
    load printers = no
    printing = bsd
    printcap name = /dev/null
    disable spoolss = yes

    # Extended ACL support
    map acl inherit = yes
    nt acl support = yes

    [homes]
    path                    = /home/%D/%U
    browsable               = no
    writable                = yes

    [userhomes$]
    path                    = /home/EXAMPLE
    comment                 = User home directories
    valid users             = @"EXAMPLE\Domain Admins"
    writable                = yes
    create mask             = 775
    directory mask          = 775
    admin users             = @"EXAMPLE\Domain Admins"

This file is pretty self explainatory. There is a bit of magic in the winbind section that sets the shell and  home directory for new users and also makes sure that Samba uses PAM (obey pam restrictions, which will be important later on). The [homes] share allows users to connect to their home directories which contains their web space. The second share is optional, [userhomes$]. This is a hidden share that is only available to domain admins that will allow them to browse all users home directories.


Finally we will want to start Samba and winbind and also make sure they start upon boot.

    Finally we will want to start Samba and winbind and also make sure they start upon boot.

    # /etc/init.d/smb start
    # /etc/init.d/winbind start
    # chkconfig smb on
    # chkconfig winbind on

Step 4: Join server to the domain
---------------------------------

This step will go over joining the server to the AD domain. Just like we would join a Windows XP machine, Server 2003, Server 2008 etc… member server to provide authentication services, so to do we join the server to provide the same services. The process is slightly more detailed but is still fairly easy.

First, we use kinit to get a Kerberos ticket and to test Kerberos is working

    # kinit Administrator@EXAMPLE.COM
    Password for Administrator@EXAMPLE.COM

Now do the join

    # net ads join -U Administrator
    Administrator's password
    Joined 'WEBS' to realm 'EXAMPLE.COM'

Now test that we can get users and groups from AD.

    # wbinfo -u

and

    # wbinfo -g

If you can see users and groups of your domain, great! If not, you most likely got an error with the join. Double check some key areas such as your /etc/resolv.conf, hosts file and make sure that winbind is running. Also check your /var/log/samba/winbindd.log for any clues

Step 5: Edit the nsswitch.conf file
-----------------------------------

The nsswitch.conf file is the configuration file for the Name Service Switch. Basically it allows you to add and order the methods for looking up account information on the server. This is different from PAM. PAM gives us the authentication, but the Name Service Switch provides the server with account information typically found in a normal /etc/passwd file and /etc/group file. For example, if you want to chown a file to a domain user, nsswitch will lookup the databases configured, look in the local /etc/passwd file and then will use winbind to lookup that user on the domain if they don’t exist in the passwd file.

Edit the /etc/nsswitch.conf file so that winbind is added as a lookup method for passwd and group.

**file: /etc/nsswitch.conf**

    passwd:     files winbind
    shadow:     files
    group:      files winbind

Leave the rest untouched.

Step 6: Edit the fstab
----------------------

This is not really nesessary, but will allow you to set file permissions through Windows on files hosted on the server. We need to add the acl flag to the mount options of the file system where the user homes are. In this instance, there is only one partition, /. Remove the **defaults** option and replace it with **rw,acl**

**file: /etc/fstab**

    LABEL=/                 /                       ext3    rw,acl        1 1

Now we need to remount the file system using the following command:

    # mount -o remount /

This should take a few seconds. Now your file system is mounted with extended ACL support. Not only will it mean that samba can set permissions, but you will also be able to set more than the 3 default permissions (owner, group, others) on files and folders.

Step 7: Add winbind as a PAM module
-----------------------------------

This will give us the authentication to the server and will allow PAM aware programs (SSH, vsftpd) to know who we are and authenticate us. We need to add it to the auth, account and session parts of PAM. Open the /etc/pam.d/system-auth file and make the following changes:


**file: /etc/pam.d/system-auth**

    #%PAM-1.0
    # This file is auto-generated.
    # User changes will be destroyed the next time authconfig is run.
    auth        sufficient    pam_winbind.so
    auth        required      pam_env.so
    auth        sufficient    pam_unix.so nullok try_first_pass
    auth        requisite     pam_succeed_if.so uid >= 500 quiet
    auth        required      pam_deny.so

    account     sufficient    pam_winbind.so
    account     required      pam_unix.so
    account     sufficient    pam_succeed_if.so uid < 500 quiet
    account     required      pam_permit.so

    password    requisite     pam_cracklib.so try_first_pass retry=3
    password    sufficient    pam_unix.so md5 shadow nullok try_first_pass use_authtok
    password    required      pam_deny.so

    session     sufficient    pam_winbind.so
    session     optional      pam_keyinit.so revoke
    session     required      pam_limits.so
    session     [success=1 default=ignore] pam_succeed_if.so service in crond quiet use_uid
    session     required      pam_unix.so

Take note of the warning up the top. authconfig will regenerate the file if it is run. Luckily, it seems the only way this is run is if you run it yourself. Upgrading CentOS versions (5.0 – 5.1 etc…) does not run authconfig again which I thought it might. Just remember what you did or write it down somewhere else incase it does get wiped.

Before you get ahead of yourself and try to login with SSH, we need to do a couple more things.

Step 8: Edit the user skeleton directory
----------------------------------------

The directory contained in /etc/skel is the directory where all new user accounts are sourced from. At the very least we need to add a folder to it so that all users will have a public_html directory. If you want to edit any other settings or add any default files or folders that all new user accounts will have, add them in here.

    # mkdir /etc/skel/public_html

This will make sure that all new user accounts will have a public_html directory. This directory is the web root for the user.

Step 9: Add the pam_mkhomedir module
------------------------------------

The pam_mkhomedir module will automatically create the user’s home directory if it does not already exist. This saves us having to write scripts that would get all the users out of AD and create their home directories for example. We add it to the system-auth file.

**file: /etc/pam.d/system-auth**

    #%PAM-1.0
    # This file is auto-generated.
    # User changes will be destroyed the next time authconfig is run.
    auth        sufficient    pam_winbind.so
    auth        required      pam_env.so
    auth        sufficient    pam_unix.so nullok try_first_pass
    auth        requisite     pam_succeed_if.so uid >= 500 quiet
    auth        required      pam_deny.so

    account     sufficient    pam_winbind.so
    account     required      pam_unix.so
    account     sufficient    pam_succeed_if.so uid < 500 quiet
    account     required      pam_permit.so

    password    requisite     pam_cracklib.so try_first_pass retry=3
    password    sufficient    pam_unix.so md5 shadow nullok try_first_pass use_authtok
    password    required      pam_deny.so

    session     required      pam_mkhomedir.so skel=/etc/skel umask=0022 silent
    session     sufficient    pam_winbind.so
    session     optional      pam_keyinit.so revoke
    session     required      pam_limits.so
    session     [success=1 default=ignore] pam_succeed_if.so service in crond quiet use_uid
    session     required      pam_unix.so

Add the section in bold to the file and save it. At this stage, AD users should be able to login using SSH and have their home directory automatically created for them. They should also be able to access their home directory through SMB/CIFS using a UNC path and if they are already logged into the domain they will not need to enter their credentials in again. Any other PAM aware applications that you also have installed on your server should also use AD to authenticate as well. In the next section, we will setup Apache to serve pages out of user home directories and also setup FTP for users to be able to access their home directories and upload files to their website.

Step 10: Setup Apache
---------------------

We will now install and configure Apache to serve pages out of the users public_html directory. First, install Apache with yum and set it to start upon boot. Don’t start it yet though, we need to make a few changes to its config.

    # yum install httpd
    # chkconfig httpd on

Now open up /etc/httpd/conf/httpd.conf and scroll down to about line 350. Make the following changes in **bold** to the file and save it.

<pre>
&lt;IfModule mod_userdir.c&gt;
    #
    # UserDir is disabled by default since it can confirm the presence
    # of a username on the system (depending on home directory
    # permissions).
    #
    # To enable requests to /~user/ to serve the user's public_html
    # directory, remove the "UserDir disable" line above, and uncomment
    # the following line instead:
    #
    <strong>UserDir public_html</strong>

&lt;/IfModule&gt;

<strong>
&lt;Directory "/home/EXAMPLE/*/public_html"&gt;
        # Allow indexes
        Options +Indexes
&lt;/Directory&gt;
</strong>
</pre>

This will enable user directories and also enable directory indexes for all users. Directory indexes will display a list of files and folders if there is no index.html, index.php etc… file. Some people choose not to enable this as it can be considered a bit of a security threat. This is true in some situations, but for the purpose of this server, I feel it makes it more functional having them turned on.

Now we will go ahead and start Apache.

    # /etc/init.d/httpd start

Apache should start with no problems. Now go ahead and login as a domain user through SSH or SMB/CIFS and put something in their public_html directory. Apache serves user directories out of **http://servername/~username**. So in our setup, assuming we logged in as the user, **user1**, the URL would be **http://webs/~user1**. This would point to the root of user1’s public_html directory.

Step 11: Setup vsftpd
---------------------

Vsftpd – Very Secure File Transfer Protocol Daemon, is the standard FTP server that ships with CentOS. Make sure it is installed via yum.

    # yum install vsftpd

We need to edit the config file to change a few settings and to make sure that it uses PAM for its user database. Anything in bold you will need to change from the defaults.

**file: /etc/vsftpd/vsftpd.conf**

<pre>
# Example config file /etc/vsftpd/vsftpd.conf
#
# The default compiled in settings are fairly paranoid. This sample file
# loosens things up a bit, to make the ftp daemon more usable.
# Please see vsftpd.conf.5 for all compiled in defaults.
#
# READ THIS: This example file is NOT an exhaustive list of vsftpd options.
# Please read the vsftpd.conf.5 manual page to get a full idea of vsftpd's
# capabilities.
#
# Allow anonymous FTP? (Beware - allowed by default if you comment this out).
<strong>anonymous_enable=NO</strong>
#
# Uncomment this to allow local users to log in.
local_enable=YES
#
# Uncomment this to enable any form of FTP write command.
<strong>write_enable=YES</strong>
#
# Default umask for local users is 077. You may wish to change this to 022,
# if your users expect that (022 is used by most other ftpd's)
<strong>local_umask=022</strong>
#
# Uncomment this to allow the anonymous FTP user to upload files. This only
# has an effect if the above global write enable is activated. Also, you will
# obviously need to create a directory writable by the FTP user.
#anon_upload_enable=YES
#
# Uncomment this if you want the anonymous FTP user to be able to create
# new directories.
#anon_mkdir_write_enable=YES
#
# Activate directory messages - messages given to remote users when they
# go into a certain directory.
dirmessage_enable=YES
#
# Activate logging of uploads/downloads.
xferlog_enable=YES
#
# Make sure PORT transfer connections originate from port 20 (ftp-data).
<strong>#connect_from_port_20=YES</strong>
#
# If you want, you can arrange for uploaded anonymous files to be owned by
# a different user. Note! Using "root" for uploaded files is not
# recommended!
#chown_uploads=YES
#chown_username=whoever
#
# You may override where the log file goes if you like. The default is shown
# below.
#xferlog_file=/var/log/vsftpd.log
#
# If you want, you can have your log file in standard ftpd xferlog format
xferlog_std_format=YES
#
# You may change the default value for timing out an idle session.
#idle_session_timeout=600
#
# You may change the default value for timing out a data connection.
#data_connection_timeout=120
#
# It is recommended that you define on your system a unique user which the
# ftp server can use as a totally isolated and unprivileged user.
#nopriv_user=ftp
#
# Enable this and the server will recognise asynchronous ABOR requests. Not
# recommended for security (the code is non-trivial). Not enabling it,
# however, may confuse older FTP clients.
#async_abor_enable=YES
#
# By default the server will pretend to allow ASCII mode but in fact ignore
# the request. Turn on the below options to have the server actually do ASCII
# mangling on files when in ASCII mode.
# Beware that on some FTP servers, ASCII support allows a denial of service
# attack (DoS) via the command "SIZE /big/file" in ASCII mode. vsftpd
# predicted this attack and has always been safe, reporting the size of the
# raw file.
# ASCII mangling is a horrible feature of the protocol.
#ascii_upload_enable=YES
#ascii_download_enable=YES
#
# You may fully customise the login banner string:
<strong>ftpd_banner=Welcome to example.com WEBS FTP server!</strong>
#
# You may specify a file of disallowed anonymous e-mail addresses. Apparently
# useful for combatting certain DoS attacks.
#deny_email_enable=YES
# (default follows)
#banned_email_file=/etc/vsftpd/banned_emails
#
# You may specify an explicit list of local users to chroot() to their home
# directory. If chroot_local_user is YES, then this list becomes a list of
# users to NOT chroot().
#chroot_list_enable=YES
# (default follows)
#chroot_list_file=/etc/vsftpd/chroot_list
#
# You may activate the "-R" option to the builtin ls. This is disabled by
# default to avoid remote users being able to cause excessive I/O on large
# sites. However, some broken FTP clients such as "ncftp" and "mirror" assume
# the presence of the "-R" option, so there is a strong case for enabling it.
#ls_recurse_enable=YES
#
# When "listen" directive is enabled, vsftpd runs in standalone mode and
# listens on IPv4 sockets. This directive cannot be used in conjunction
# with the listen_ipv6 directive.
listen=YES
#
# This directive enables listening on IPv6 sockets. To listen on IPv4 and IPv6
# sockets, you must run two copies of vsftpd whith two configuration files.
# Make sure, that one of the listen options is commented !!
#listen_ipv6=YES

<strong>
pam_service_name=vsftpd
userlist_enable=YES
tcp_wrappers=YES
chroot_local_user=YES
session_support=YES
</strong>
</pre>

Save and close the file. An important line in the file is session_support=YES. This is not talking about an FTP session, but rather to make sure to use PAM session support. This means that it will run the pam_mkhomedir module and any other session modules that we configure. Now start proftpd and also don’t forget to add it to start on boot.

    # /etc/init.d/vsftpd start
    # chkconfig vsftpd on

Thats it! You can stop now and you will have a fully functional shell/web server for users of your Active Directory. If you continue I will go over setting up quotas, securing access using IPTables and allowing the Domain Admins group root access.

Step12: Optional - Setup quotas
-------------------------------

Quotas will limit the amount that users are allowed to store on the server. This prevents users using their webspace to host large files which is probably what we want as administrators. The quotas can be based on a group so that in this case, anyone who is a member of the group “students” will be alloted 100MB. Note that this support of quotas based on groups is not Linux “group quotas” which will allot a group of users an overall quota. Also note that this support of quotas based on groups is not natively supported, but will can be by using a script that is executing upon login using PAM.

But before we go into details, we need to setup quota support on the file system. This guide assumes that you have just one partition, your root partition. If you have your /home on another partition, then set the quota options to your /home partition. We will edit the /etc/fstab file to enable the support and then remount the file system.

**file: /etc/fstab**

    LABEL=/                 /                       ext3    rw,acl,usrquota 1 1
    tmpfs                   /dev/shm                tmpfs   defaults        0 0
    devpts                  /dev/pts                devpts  gid=5,mode=620  0 0
    sysfs                   /sys                    sysfs   defaults        0 0
    proc                    /proc                   proc    defaults        0 0
    LABEL=SWAP-sda2         swap                    swap    defaults        0 0

Remember to remount

    # mount -o remount /


Add the **usrquota** option to enable user quotas. Now we need to create the file that will store the user quotas.

    # touch /aquota.user
    # chmod 600 /aquota.user
    # chown root:root /aquota.user

Now we run quotacheck to get the most recent state of our quotas.

    # quotacheck -vgum /

Quota support is now enabled. Now there are a few ways to apply quotas to users. We can use the command line programs to manually apply quotas to users (very undesirable), write a script that fetches all the users in AD and applies a quota to each user every hour or so (also undesirable), use the **pam_setquota** module, or use the **pam_script** module and run a script at the PAM session stage. I couldn’t get the pam_setquota module to compile (latest source I could get was 2006), so I used the pam_script module and wrote a script that would run whenever a user logged in, used samba or used FTP. Create the following script in /usr/local/bin/quota_set.sh.

**file: /usr/local/bin/quota_set.sh**

    #!/bin/bash
    # Sets the users quota to 100MB if they are a student
    #
    # Get the user name
    user=$1

    # Will return a string if the user is a student
    retval=`groups $user`

    # If the user is a student, then set the quota to 100MB
    if [[ $retval =~ " student " ]]
    then
      # Set the quota of the user to 100MB, with a 120MB hard limit
      setquota -u $user 100000 120000 0 0 -a /
    fi

Read through the comments to see how it works. Change the bolded value to match the group of your users. In this instance, all students are members of the AD group “student”. Note that anyone with the string ” student ” (note the spaces between student) will have this quota applied to them. Also feel free to change the amount of quota users get (the 100000 and 120000 values, where 1 = 1kB).

Also don’t forget to make it executable.

    # chmod +x /usr/local/bin/quota_set.sh

Now we need to add this as a parameter of the pam_script module. First lets make sure that pam_script is installed.

    # yum install pam_script

Now edit the /etc/pam.d/system-auth file to include this module

**file: /etc/pam.d/system-auth**

    #%PAM-1.0
    # This file is auto-generated.
    # User changes will be destroyed the next time authconfig is run.
    auth        sufficient    pam_winbind.so
    auth        required      pam_env.so
    auth        sufficient    pam_unix.so nullok try_first_pass
    auth        requisite     pam_succeed_if.so uid >= 500 quiet
    auth        required      pam_deny.so

    account     sufficient    pam_winbind.so
    account     required      pam_unix.so
    account     sufficient    pam_succeed_if.so uid < 500 quiet
    account     required      pam_permit.so

    password    requisite     pam_cracklib.so try_first_pass retry=3
    password    sufficient    pam_unix.so md5 shadow nullok try_first_pass use_authtok
    password    required      pam_deny.so

    session     required      pam_mkhomedir.so skel=/etc/skel umask=0022 silent
    session     required      pam_script.so runas=root onsessionopen=/usr/local/bin/quota_set.sh
    session     sufficient    pam_winbind.so
    session     optional      pam_keyinit.so revoke
    session     required      pam_limits.so
    session     [success=1 default=ignore] pam_succeed_if.so service in crond quiet use_uid
    session     required      pam_unix.so

When a user opens a session (using FTP, logging into SSH etc…) this script will be run and will set the user’s quota. Note that the quota can be changed later down the track as the script will run everytime a PAM session is created.

Step 13: Optional – Setup IPTables
----------------------------------

This step will be dependant on the hostility of the users. This server was originally comissioned for use in a school environment. The possibility for users to use this server as a tunnel out to the Internet was not just a possibility, but a ceartainty. But what about PHP proxy scripts you might ask? Well that can be solved as well. We will use IPTables user matching module to allow outgoing connetions to only ceartain user groups. The idea of matching users based on their group might sounnd really cool, and that’s because it is.

CentOS luckily has this support already enabled. Below is the firewall script that I use and it works quite well. Create a file /etc/sysconfig/firewall.sh and add the following:

**file: /etc/sysconfig/firewall.sh**

<pre>
#!/bin/bash
# Flush tables
iptables -F

# Set defaults
iptables -P INPUT DROP
iptables -P OUTPUT DROP
iptables -P FORWARD DROP

########## INPUT RULES ##########
# Stateful inpection input
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
# Allow HTTP
iptables -A INPUT -p tcp --dport 80 -j ACCEPT
# Allow SSH from internal network
iptables -A INPUT -s 192.168.0.0/24 -p tcp --dport 22 -j ACCEPT
# Allow FTP
iptables -A INPUT -p tcp --dport 21 -j ACCEPT
# Allow ping
iptables -A INPUT -p icmp --icmp-type echo-request -j ACCEPT

######### OUTPUT RULES ##########
# Set some default outgoing rules that are allowed
<strong>iptables -A OUTPUT -m state --state ESTABLISHED -j ACCEPT</strong>
iptables -A OUTPUT -p udp --dport 53 -j ACCEPT

# Only allow domain admins and root to make new outgoing connetions that
# are not pre-defined
#
# Need to do this so students don't use this server to tunnel to the
# internet, access web, ssh to different servers etc...
#
# Accepted users
#
<strong>iptables -A OUTPUT -m owner --gid-owner domain\ admins -j ACCEPT</strong>
<strong>iptables -A OUTPUT -m owner --gid-owner root -j ACCEPT</strong>
<strong>iptables -A OUTPUT -p tcp --sport 80 -m owner --uid-owner apache -j ACCEPT</strong>
#
# Rejected users
#
<strong>iptables -A OUTPUT -m owner --gid-owner domain\ users -j REJECT</strong>
<strong>iptables -A OUTPUT -m owner --gid-owner apache -j REJECT</strong>

# Finally accept new connections if no other match is made
iptables -A OUTPUT -m state --state NEW -j ACCEPT
</pre>

The important lines are at the end of the file **bolded**. By default, we want to make sure that the AD group “Domain Admins” is allowed to make new connections as well as the “root” group. Also, the rule matching the Apache user with a source port of 80 is important as we want to make sure Apache is allowed to send out packets from its sessions but we want to restrict it from sending out new connections which would be the Apache user attempting to access a web site to proxy to the user. We then need to REJECT users that haven’t matched already. The AD group “Domain Users” will be denied access as well as Apache from making outgoing connections.

Now we want to make the file executable and add it to the /etc/rc.local. There is a “correct” way to do firewalling/IPTables in CentOS but I prefer to write a firewall script and run it on boot.

    # chmod 700 /etc/sysconfig/firewall.sh
    # chown root:root /etc/sysconfig/firewall.sh
    # echo "/etc/sysconfig/firewall.sh" >> /etc/rc.local

Apply the firewall and make sure everything still works

    # /etc/sysconfig/firewall.sh

NOTE: You might notice that all users are allowed to ping. This is because an ICMP ping packet is generated in the kernel space and not in userland programs, therefore the owner of the packet is root and not the user. Try using links or wget to confirm that the user matching works as these packets will be owned by the user that is requesting them.

Step 14: Optional - Setup sudo
------------------------------

Sudo, or super user do, allows you run or do things as root using your normal user account. You don’t need to know the root password, but just have to be in the /etc/sudoers file. You can allow users to do everything, or just a select few things. What we want to do is allow Domain Admins full access to the server, like they have full access to other member servers (by default).

We can’t edit the sudoers file directly, but rather have to edit it using the visudo command. Add these lines after you have run visudo

    # visudo

**file: /etc/sudoers**

    ## Allows domain admins root privilages using their password
    %Domain\ Admins	ALL=(ALL)	ALL

Now Domain Admins will have root prviliges using their current credentials.

Conclusion
----------

You should now have a web/shell/FTP server that will authenticate off Active Directory. If you chose to add in the extra steps, your server will be even more secure against possible misuse. There are more things that you can do such as emailing users who have gone over their quota and searching for and deleting media files (mp3, avi, etc…). I’ll leave these things up to you if you wish to implement them.

Feel free to comment with suggestions, questions or to correct any mistakes.
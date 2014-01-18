---
layout: post
title:  "NTLM with Apache + CentOS 5"
date:   2007-07-09 22:20:01
comments: true
---

NOTE: I have since used a different method for NTLM authentication. I found that this perl variant of NTLM had problems when a high load was put on the web server. There is a modification of the original auth_ntlm module to work with Apache 2.2 avaliable here

I thought I would document this as it is one of the most seemingly simplest but hardest things that I have done. There is a lot of documentation around, but nothing that I followed seemed to work.

First off we will want a fresh install of CentOS. For the test server I used 4.4, but the new production server the latest version, 5 was used. To keep the size down, don’t bother installing any extra packages. Keep it as minimal as possible, as we will install all the needed packages later.

Once you have booted into your new CentOS 5 system, we will want to update all the packages to their latest version. Login as root and enter the following command

    yum update

Accept all the packages and let it download and install them. If you notice that the kernel gets updated, you will need to reboot your server in order for this change to take place. Otherwise, you wont need to reboot. Next we will install Apache

Install Apache using the following command at the shell

    yum install httpd

Once this is installed, we need to install the appropriate development tools to be able to compile the perl NTLM module.

    yum groupinstall “Development Tools”

This will take a while for the packages to download and for them to install. Once this is finished, you will need to download the perl module from. NOTE: We dont want the module Authen::perl::NTLM. This is included in the dag repository, found here. This repository is great and includes heaps of packages, something that you will probably want to add at a later date, but for now, we will need to build the module from source.

The module that we want is Apache2::AuthenNTLM. As far as I know it is not readily avaliable as an installable RPM so we will need to download the source and comple it manually.

    cd /tmp
    wget http://search.cpan.org/CPAN/authors/id/S/SP/SPEEVES/Apache2-AuthenNTLM-0.02.tar.gz
    tar zxvf Apache2-AuthenNTLM-0.02.tar.gz
    cd Apache2-AuthenNTLM-0.02
    perl Makefile.pl
    make install

You shouldn’t have any errors at compile time as long as you installed the “Development Tools” group package.

Thats all for the installation. All that needs to be done now is some configuration in the Apache config file. Firstly, keepalives need to be enabled. NTLM authentication simply won’t work without it. Open the file in Vim for editing.

    vim /etc/httpd/conf/httpd.conf

Make sure the **KeepAlive** option is set to be **On**. Save and exit

Now we need to set security on the file or directory which we want to protect with NTLM. This can be done with a .htaccess file or it can be programmed into the httpd.conf file or any vhost includes. For simplicity sake, we will make a directory called “secure” in the default webroot

    mkdir /var/www/htlm/secure

We now need to edit the httpd.conf file to include the following:

    <Directory “/var/www/htlm/secure”>
    Options Indexes
    PerlAuthenHandler Apache2::AuthenNTLM
    AuthType ntlm,basic
    AuthName Secure Access
    require valid-user
    PerlAddVar ntdomain “YOURDOMAIN domaincontroller backupdomaincontroller”
    PerlSetVar defaultdomain YOURDOMAIN
    PerlSetVar splitdomainprefix 1
    PerlSetVar ntlmdebug 0
    PerlSetVar ntlmauthoritative off
    </Directory>

This will now only let a user from your domain to access the contents of the secure directory.

Save the http.conf file and restart Apache. To test if authentication is working correctly, navigate you the secure directory at http://server.ip.addre.ss/secure. After you authenticate with a domain user and password, it should show a directory listing. Currently, there is nothing in the directory, but at least is demonstrates that NTLM is actually getting its auth data off Active Directory.

The next part is easy. All it involves is adding whatever site you configured Apache to use with authentication to the trusted zone in Internet Explorer. This can be done manually or configured as a GPO and deployed site wide. I noticed that even though IE detected I was in an intranet zone, it still failed to pass the NTLM auth to Apache and had a prompt for a user name and password.

Well thats about it. I hope this helps some others that just couldn’t get NTLM working correctly. Unfortunately, there is no group support with the Perl version on NTLM. There is a winbind NTLM module available that you can use that does provide some basic group support, but I couldn’t get this to work properly. Just remember that you need to add the site you are using to the trusted zone of IE. Once you go to the secured site, there should be a green tick on the bottom part of the window of IE. If this is the case, it is considered trusted.

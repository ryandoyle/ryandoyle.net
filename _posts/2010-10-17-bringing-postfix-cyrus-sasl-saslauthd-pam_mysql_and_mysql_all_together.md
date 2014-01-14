---
layout: post
title:  "Bringing Postfix, Cyrus SASL, saslauthd, pam_mysql & MySQL all together"
date:   2010-10-17 18:16:34
---

I have had a constant battle with getting SASL authentication working within Postfix. My email accounts are stored in a MySQL database with MD5 encrypted passwords. I use Courier Authlib (authdaemond) to authenticate IMAP users fine, but I could never get Postfix/Cyrus talking correctly with authdaemond. I decided to look at other ways I could get SASL authentication working without Courier Authlib and this is a result of that effort. This setup assumes you are using CentOS/RHEL 5. Other distributions may have its files in different locations or already have the correct PAM packages in their software repository.

Failure with Courier Authlib (authdaemond)
------------------------------------------
This flowchart shows what should have worked. As Courier IMAP talks fine to Courier Authlib, it would have been nice to get Cyrus SASL/Postfix also talking to Courier Authlib. But try as I might, I could never get it to work. My guess is that Cyrus SASL needs support compiled into it for talking with authdaemond.

![SASL Authentication with authdaemond](/assets/posts/sasl_authdaemond.png)

Success with saslauthd/pam_mysql
--------------------------------
While the above would be ideal, I looked at other ways to get SASL authentication working. I then came across using saslauthd (part of Cyrus SASL) and then plugging this into PAM with pam_mysql. Below shows the flowchart.

### Getting the pam_mysql module ###
I built the pam_mysql module for CentOS/RHEL 5 x86_64. You can just [download](http://files.doylenet.net/linux/packages/rhel/5/doylenet/RPMS/x86_64/pam_mysql-0.7RC1-2.x86_64.rpm) the pam_mysql RPM and install it or add my Yum repository.

Via RPM. Yum-priorities is a dependency of this RPM and by default is set as a priority of 10.

    wget http://files.doylenet.net/linux/packages/rhel/5/doylenet/RPMS/x86_64/\
      doylenet-repo-rhel5-1.0-1.noarch.rpm
    rpm -Uvh doylenet-repo-rhel5-1.0-1.noarch.rpm
    yum install pam_mysql

Or if you would prefer to manually add the repository Put the following in /etc/yum.repos.d/Doylenet.repo

    [doylenet]
    name=Doylenet repository for RHEL/CentOS
    baseurl=http://files.doylenet.net/linux/packages/rhel/5/doylenet/RPMS/x86_64/
    gpgcheck=1
    gpgkey=http://files.doylenet.net/linux/packages/rhel/RPM-GPG-KEY-doylenet
    enabled=1
    priority=10

Then

    yum install pam_mysql

I don’t have an i386 version so you would need to download the SRPM from here and build it. I have modified the pam_mysql.spec file to put the pam_mysql.so module in the correct lib directory depending on the architecture as before it was statically set to /lib.

![SASL Authentication with Cyrus SASL/saslauthd/pam_mysql](/assets/posts/sasl_pam_mysql.png)

To try and explain everything a bit better, I’ll go through the important configuration lines and describe what they do.

### Postfix ###
- **smtpd_sasl_path** - This tells Postfix where to look for the Cyrus SASL configuration file. smtpd refers to /usr/lib64/sasl2/smtpd.conf
- **smtpd_sasl_type** - Postfix defaults to Cyrus, but it is best to make sure it is set. Dovecot can also be used for SASL authentication.


### Cyrus SASL ###
- **pwcheck_method** - Tells Cyrus what method it will use to check users for. In the first flowchart, authdaemond was selected but now we are using saslauthd. Note that you can also specify the MySQL details directly in here using the MySQL auxprop plugin omitting the need for PAM, but passwords need to be stored in plain text for this to work.
- **mech_list** - Specifies what type of authentication passing mechanisms can be used. These need to be plain text so make sure that Postfix is running with TLS/SSL support.


### saslauthd ###

- **MECH** - Specifies how saslauthd should look up its users. It does not have support directly for MySQL so we need to an another layer and tell it to use PAM and then get PAM talking with MySQL.
- **FLAGS** - These are arguments passed to saslauthd when it is started up. The -r argument stops saslauthd from breaking up the user name (user@example.com) into separate parts. Without this argument, saslauthd would give PAM a user name of user and then give a realm of example.com. What this would mean, when pam_mysql was looking up the user name it would be asking for only user and not user@example.com.


### pam_mysql ###

You can probably guess what these lines do. They specify the MySQL details and where to get the user name and password. One important argument to pam_mysql.so is the **crypt** argument. Passing an argument of 1 uses the crypt function. There are other methods and these can be found in the pam_mysql README.
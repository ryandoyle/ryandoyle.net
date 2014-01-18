---
layout: post
title:  "LDAP Authentication with Apache2 using Acitve Directory"
date:   2007-07-19 11:59:01
comments: true
---

LDAP authentication in Apache allows user and group authentiction from Active Directory to provide secutiry for files and folders using the users domain credentials. The only downfall of using LDAP authentication is that it isn’t SSO (Single Sign On). The user name and password used to authenticate is the same, but the browser doesn’t pass this info on like NTLM does. Anyhow, it is a useful authentication method regardless, as NTLM lacks proper group support in Apache.

Like everything else, this will be built using CentOS5. Install it in a minimal install. I will go through the packages that need to be installed next. Once CentOS is installed and up and running, login and we will install Apache. The default httpd package includes LDAP suppor, so we don’t need to install any other modules for it. There is a module called mod_authz_ldap. When I was originally setting this up, I thought that this was required, but didn’t realise that Apache supported LDAP out of the box.

Before we install Apache, we may as well update the all packages of the system.

    yum update

This will take a while to complete and may download a few hundred MB of updates depending on what you installed. When this is complete, we will install Apache2

    yum install httpd

This should only be a little over a MB. Once this is installed, we will create a directory that we want secured. For simplicity sake, we will just create it in the default web root. It can be applied for vhosts etc… as well.

    mkdir /var/www/htlm/secure

Just to test it, we will make a simple web page in this folder

    echo “<htlm><h1>It works!</h1></html>” > /var/www/htlm/secure/index.html

Now we will edit the /etc/httpd/conf/httpd.conf file to apply security to the “secure” directory. This can also be achieved using a htaccess file, but I really DON’T like htaccess files. They are harder to organise than applying security settings directly to vhost files of the httpd.conf file. Open the httpd.conf file in Vim

    vim /etc/httpd/conf/httpd.conf

Go right to the end of the config (just hold page down) . Oncethere we want to enter the following.

    <Directory “/var/www/htlm/secure”>
    AuthType Basic
    AuthName “LDAP Authentication”
    AuthBasicProvider ldap
    AuthLDAPURL ldap://dc.example.com:389/OU=USEROU,DC=example,DC=com?sAMAccountName?sub?(objectClass=user)
    AuthLDAPBindDN cn=binduser,ou=SPECIAL,ou=USEROU,dc=example,dc=com
    AuthLDAPBindPassword bindparseword
    AuthzLDAPAuthoritative off
    require ldap-group cn=Staff,ou=GROUPS,ou=USEROU,dc=example,dc=com
    </Directory>

Once this is entered, save it. We need to now create the bind user. The orginisational units may change depending on your directory structure so you can go back into the httpd.conf file to change these accordingly.

Open Active Directory Users and Computers and navigate to where you want to create your bind user. In this example, we have an orginisational unit under the domain root called USEROU and the bind user in an OU called SPECIAL. Make the name of the user “binduser”. The first and last name can be “bind” and “user” respectivly, but make sure that the display name doesn’t include the space. Make the username binduser as well. As for the password, this is up to you. Make sure it reflects what is in the httpd.conf file.

Once this user is created, make sure that any changes in the location of the user is relflected in the httpd.conf file.

Als, before I forget, make sure that the hosts file is configured corectly. I have had some trouble when Apache doesn’t look up the name of the server using the name servers in the /etc/resolv.conf file. Add the server name to the hosts file as shown below. Of course, change your IP and name of the server to that of your orginisation.

    echo “10.0.0.20 dc dc.example.com” >> /etc/hosts

Now start Apache

    /etc/init.d/httpd restart

Now nagivate to the address of your web server and try to access the /secure directory. If it is successful you should be asked for a username and password. If you are a member of the “Staff” group or any group that you specified in the httpd.conf file you should see the “It Works!” text on the screen. If this is not the case have a look in the Apache log files for a clue. On thing that I find useful is changing the LogLevel to “debug” if there is nothing in the error logs that I can see. The most common error that there really is is getting the right syntax for the LDAP distinguished name. Double check that is is correct before looking at other errors.

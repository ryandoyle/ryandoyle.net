---
layout: post
title:  "Getting groups on the cheap with Apache/NTLM"
date:   2007-07-09 22:12:01
comments: true
---

I previously explained the setup for Apache with NTLM authentication. This is all well and good if you want to only authenticate with a few users in a manual htaccess file or if you want to only let members of the domain authenticate, but it not the greatest at getting group information.

A lot of the time groups are more useful than managing users and good practices say that permissions should practically be all based on groups. There are two ways to perform group authentication. The first way is based on the web application that you are restricting. If you have control over it and its coded in PHP, it can be hacked to enable tranparent authentication. This can be difficuilt, but not hard to perform if the application has been coded by yourself. The second method is based on a htaccess style method of authentication.

I opted for the second type of authentication. I wrote a script that got the users from Active Directory and then checked each one of they were a mamber of a specific group. It is a bit messy, but seemed the easiest and more secure.

{% highlight php %}
// bind to the domain
include (“adLDAP.php”);
$ldap=new adLDAP();

// connect with the bind username and password
$ldap->authenticate(“binduser”,”binduserpassword”) or die(“Could not connect with the supplied user name and password\n”);

// List all users in the directory
$result=$ldap->all_users($include_desc = false, $search = “*”, $sorted = true);

// Setup the user string variable
$userstring = “require user “;

/* Run the loop checking which users are members of the staff group, add their name to the userstring variable */
for($i=0; $i < sizeof($result); $i++){
if(($ldap->user_ingroup($result[$i],”Staff”))== true){
$userstring = $userstring.$result[$i].” “;
}
}

// Write results to file
$fh = fopen(“/etc/httpd/vhost.d/example.com/secure”, ‘w’) or die(“cannot open file”);

$vhostfile1 = “<VirtualHost *:80>
DocumentRoot    \”/var/www/example.com/secure\”
ServerName      \”secure.example.com\”
ServerAlias     \”secure\”
ErrorLog logs/secure.example.com_error_log
CustomLog logs/secure.example.com_access_log common

<Directory \”/var/www/example.com/secure\”>
PerlAuthenHandler  Apache2::AuthenNTLM
AuthType ntlm,basic
AuthName test
“;

$vhostfile2 = ”
PerlAddVar ntdomain \”EXAMPLE   dc1.example.com dc2.example.com\”
PerlSetVar defaultdomain EXAMPLE
PerlSetVar splitdomainprefix 1
PerlSetVar ntlmdebug 1

</Directory>
</VirtualHost>
“;

fwrite($fh, $vhostfile1);
fwrite($fh, $userstring);
fwrite($fh, $vhostfile2);
fclose($fh);

// Restart Apache
system(“/bin/bash /etc/init.d/httpd restart”);
{% endhighlight %}

Most of the magic comes from the adldap API. You will need it to run this script and can download it from here. The other way involves listing the users in a group, but this outputs where the users are located in the directory and not simply their username.




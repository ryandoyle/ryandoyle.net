---
layout: post
title:  "PPTP using Poptop on CentOS 5"
date:   2007-10-01 12:15:01
comments: true
---

Just recently I needed to setup a quick and dirty VPN solution. I’ve used Poptop before on Mandrake 9 many years ago and it proved to be pretty easy to setup. Its even easier with CentOS 5, as the kernel is already patched with MPPE and MPPC encryption and authentication that is really required to create a secure VPN solution.

Install and configure Poptop
----------------------------

Firstly, make sure that ppp is installed using yum.

    yum install ppp

I compiled the latest pptp version so grab the RPM from here and install it or add my custom yum repository. I would reccomend the latter as yum will update PPTP if I put an updated PPTP package on my yum repo.

If you would prefer to use my yum repository which also has a few other updated packages such as the patched iptables for L7 filtering (which I will talk about in a later post), you can add it by creating a new file “/etc/yum.repos.d/Doylenet.repo” and adding the following lines

    [doylenet]
    name=Doylenet custom repository for CentOS
    baseurl=http://files.doylenet.net/linux/yum/centos/5/i386/doylenet/
    gpgcheck=1
    gpgkey=http://files.doylenet.net/linux/yum/centos/RPM-GPG-KEY-rdoyle
    enabled=1

Once you have created this file, we need to install pptpd through yum.

    yum install pptpd

Now we want to edit the /etc/pptp.conf file. Disable the line “logwtmp” by commenting it out otherwise PPTP will fail to start and get this error in the syslog, “Plugin /usr/lib/pptpd/pptpd-logwtmp.so is for pppd version 2.4.3, this is 2.4.4″. Like the error says, the library file is for PPP 2.4.3, but CentOS 5 uses 2.4.4. EDIT: This has now been corrected in the RPM package as pointed out by Peter. It is no longer required to disable this line.

Scroll down to the area localip and remoteip. So that we can keep routing issues to a minimum, set this to a range in your local LAN. For example, I use 10.0.0.0/24 for my private LAN. 10.0.0.1 is the IP address of my router and VPN server. I set the localip value to 10.0.0.2 and the remoteip range to 10.0.0.200-220, outside the DHCP assigned range.

    localip 10.0.0.2
    remoteip 10.0.0.200-220

Now edit the /etc/ppp/options.pptpd file. The defaults in here are fine as they are secure by default. The VPN will not form unless MSCHAPv2 is being used for authentication and 128bit MPPE encryption. Scroll down to “ms-dns”. It is commented out by default. Edit this to your internal DNS server address. Do this for WINS as well. If you don’t have an internal DNS server, this is fine, but name resolution is a lot less painful if you are using DNS and not relying on NetBIOS which requires broadcasts and doesn’t really work to well over a VPN.

    # If pppd is acting as a server for Microsoft Windows clients, this
    # option allows pppd to supply one or two DNS (Domain Name Server)
    # addresses to the clients. The first instance of this option
    # specifies the primary DNS address; the second instance (if given)
    # specifies the secondary DNS address.
    ms-dns 10.0.0.240
    #ms-dns 10.0.0.2# If pppd is acting as a server for Microsoft Windows or "Samba"
    # clients, this option allows pppd to supply one or two WINS (Windows
    # Internet Name Services) server addresses to the clients. The first
    # instance of this option specifies the primary WINS address; the
    # second instance (if given) specifies the secondary WINS address.
    ms-wins 10.0.0.240

Finally we want to edit the file /etc/ppp/chap-secrets. This is where we will specify user names and passwords. Each user is specified on a new line.

    username * password *

This is all the configuration that is needed as far as the PPTP server goes. Start it using the following command.

    /etc/init.d/pptpd start

Firewall and Routing
--------------------

The only issues now that need to be resolved are routing and firewall issues. This is only relevant if the VPN server is on the same server as your firewall/router. By having the VPN clients on the same subnet as the rest of the trusted LAN, it makes it easier for the client, but slightly harder to configure, as we aren’t dealing with Layer 3. We need to allow the interface ppp0 access to the trusted interface. We will assume eth0 is the trusted interface

    iptables -A INPUT -i ppp0 -j ACCEPT
    iptables -A FORWARD-i ppp0 -o eth0 -j ACCEPT

This could also be done using the 10.0.0.0/24 range, but this will only work for unicast addresses. To make these statements safe, 10.0.0.0 should be dropped at the external interface as well if not already done so. Its good practice to drop all [RFC 1918](http://www.faqs.org/rfcs/rfc1918.html) private addresses that which have their source address incoming from the external interface. A lot of malformed and spoofed IP packets often have source addresses from the private address range.

    iptables -A INPUT -i eth0 -s 10.0.0.0/24 -j ACCEPT
    iptables -A FORWARD -i eth0 -s 10.0.0.0/24 -j ACCEPT

Now we need to allow the VPN protocols that will be used to connect and communicate with the VPN server through our firewall. The authentication part of our VPN server uses the PPTP protocol which is on TCP port 1723. Actual data is then transfered using IP protocol GRE (Genertic Routing Encapsulation). Configure the following iptables commands.

    iptables -A INPUT -i $external_interface -p tcp --dport 1723 -j ACCEPT
    iptables -A INPUT -i $external_interface -p gre -j ACCEPT

Connecting a Windows client
---------------------------

Lastly, we will want to setup the client. Windows 2000 and XP and (i assume) Vista, come with a PPTP VPN client that is installed by default. You can get to it by going to the “Network Connections” dialog and clicking “Create a new connection”. Follow the wizard through selecting **Connect to the network at my workplace** > **Virtual Private Network connection** > Enter in a name for the connection > Enter in the IP or preferably DNS name of the VPN server. If the VPN server is the router/gateway, you can use your external IP address in your LAN. For testing purposes, I used the internal address of 10.0.0.1. If you run an internal DNS, use that name so when you are away from home you VPN in, it will grab the external address as long as you have set everything up properly (in terms of external DNS). For this, I reccomend you use the services provided at DynDNS or a simmilar free DNS provider.

![vpn1](/assets/posts/vpn1.JPG)

Click “Properties”.

![vpn2](/assets/posts/vpn2.JPG)

Navigate to the screen above and click “Properties” again.

![vpn3](/assets/posts/vpn3.JPG)

Then “Advanced”

![vpn3](/assets/posts/vpn3.JPG)

Then untick “Use default gateway on remote network”. This statement is important and needs to be unticked most of the time for simple VPN setups. What this means is that you existing default gateway will be used (what ever you are connecting through the internet to) for all traffic that isn’t related to the VPN. Remember how we used the same subnet for the VPN clients as the LAN clients? This is because if we used another subnet, the VPN clients would not know how to get to the LAN. This would require the **Use default gateway on remote network** to be ticked, but would also mean all unrelated traffic would go through the VPN. The technical term for this is “Split Tunneling” and can be a security concearn with larger enterprises as there is a potential for the remote user to be a gateway into the corporate network. Our setup is rather simple and we trust the users that are connecting, so this is not a concearn.

Once you have this option set, use the username and password that was set in the chap-secrets file to connect and to test your VPN.


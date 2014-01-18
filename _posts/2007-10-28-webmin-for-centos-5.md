---
layout: post
title:  "Webmin for CentOS 5"
date:   2007-10-28 23:16:01
comments: true
---

I was supprised to find that there was no RPM provided by yum for webmin; neither in the base packages or Dag repository. For anyone who wants it is is avalible using my yum repository. Add the following to a file /etc/yum.repos.d/Doylenet.repo

    [doylenet]
    name=Doylenet custom repository for CentOS
    baseurl=http://files.doylenet.net/linux/yum/centos/5/i386/doylenet/
    gpgcheck=1
    gpgkey=http://files.doylenet.net/linux/yum/centos/RPM-GPG-KEY-rdoyle
    enabled=1

You can now install it using the command below

    yum install webmin

Accessing Webmin is as easy as going to https://server:10000 and logging in with your root account.


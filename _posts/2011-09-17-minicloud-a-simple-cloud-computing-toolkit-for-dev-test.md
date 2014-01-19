---
layout: post
title:  "MiniCloud: a simple Cloud computing toolkit for Dev/Testing"
date:   2011-09-17 11:01:05
comments: true
---

I’ve been using a lot more Cloud computing tools over the last few months. While EC2 is great, it leaves you longing for the same functionality with an internal private Cloud. And there are private clouds out there. OpenStack, Eucalyptus, OpenNebula & Cloud.com are some of the more popular ones but they take a bit of work to get up and running and require their infrastructure paradigm.

MiniCloud is a small tool set that implements Cloud-like control to create, manage and destroy computing instances. It uses OpenVZ as a hypervisor to provide container-based virtualisation, suitable for development and testing.  It was created to be as simple as possible to get setup and be usable.

Let me know what you think: [https://github.com/ryandoyle/minicloud](https://github.com/ryandoyle/minicloud)

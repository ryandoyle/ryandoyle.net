---
layout: post
title:  "Building a stratum 1 NTP server with a Raspberry Pi"
date:   2014-02-07 18:47:01
comments: true
---

A [while](http://ryandoyle.net/posts/stratum-1-ntp-garmin-gps-18-lvc-on-freebsd-80/) ago, I made a stratum 1 NTP server using FreeBSD and a Garmin 18 LVC GPS. Sadly, I had to retire this server - a combination of using too much power and moving house meant that somewhere between then and now I it was turned off. A few years later with the Garmin GPS receiver and a spare Raspberry Pi in hand, I decided once again to get my NTP server up and running.

Hardware
========
Here is the hardware that I used for my NTP server

* Model B Raspberry Pi (RPi)
* Garmin 18 LVC GPS receiver
* A [serial to USB adapter](http://au.element14.com/jsp/search/productdetail.jsp?SKU=1686450)
* 3 10K Ohm resistors
* Optional: [Raspberry Pi protoboard](http://au.element14.com/jsp/search/productdetail.jsp?SKU=2301692)
* Optional: [GPIO Ribbon cable](http://au.element14.com/jsp/search/productdetail.jsp?SKU=2215033)
* USB cable for power
* Old iPhone charger for the power supply

Fortunately (or perhaps unfortunately) there is more than one way to skin a cat when it comes to interfacing with the RPi. The hardware I used here worked for me. If you know what you're doing you can interchange the GPS receiver and probably use the onboard UART instead of a serial to USB adapter. A word of warning though: **the GPIO pins an UART on the RPi operate at 3.3v. Make sure your GPS reciever also operates at 3.3v**

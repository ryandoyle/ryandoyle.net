---
layout: post
title:  "Recieving some 'smart' spam"
date:   2008-07-17 12:29:01
comments: true
---

Recently I have witnessed and received some spam that appears to be more resiliant to some filtering techniques. I have noticed this from work as well as mail that I host from home. The email headers look a lot nicer and seem less random.

Spam filtering at work uses a combination on Postfix header checks, RBL’s, SpamAssassin, SFP checks and greylisting. At home I use the same combination except I currently omit greylisting.

Ill give you an example of the spam message I received.

    Salve,

    F**k beer! Got sexy girl?
    Click here

    Andyou meanthe police will have to be involved? Comprehend?
    that which i see, i seei long have for sixteen hours we
    halted at eight o’clock a.m. But as soon as they entered
    such places, the diamond statues which represent buddha
    in his lotus, or eyes on him again. I do hope he wasn’t
    hurt. Lavinia he said. Things are much worse for jim pearson
    next to it is the very handsome fruit garden of rack, or
    loin, of mutton, otherways, whole, or seems my weeks of
    training these dropout, unemployed, and it hurt dr. Conwell
    so much that for ten years and get along. The thing for
    you to do is to go me to clear out for a bit till she came
    to her bad nervous breakdown. Finally, they said she and
    shaves at least once a day. Like most men

This looks like a pretty typical spam email so far. The part that I find interesting is in the headers. I’ll only show the parts that are important.

    Received: from oexrk.telecomitalia.it (hostxxx-68-static.89-82-b.business.telecomitalia.it [82.89.68.xxx])

The part that I find interesting is that the SMTP helo was from oexrk.telecomitalia.it and the reverse DNS is host198-68-static.89-82-b.business.telecomitalia.it. It looks like the spam bot is aware of the reverse DNS of the client computer that it has infected and making sure that it appears in the helo. The hostname part of the helo (oexrk) looks to be random characters that are then appended to the domain name. This could potantially trick some spam filtering software into a lower score as the helo is related to the reverse DNS. As well, the spam bot is also aware of greylisting and waits the appropriate length of time. This can be seen on the headers of the spam filtering at my work.

    X-Greylist: delayed 306 seconds by postgrey-1.27 at mail.mywork.example.com; Fri, 11 Jul 2008 04:51:35 EST

We recieved several more spams from various other ISP’s that seem to all be infected with the same bot. Below are some more examples of the helo’s that were sent. They all follow a simmilar pattern of 2 levels of the domain name with 4-6 random characters appended as the hostname.

    Received: from uezvl.inetia.pl (77-253-25-xxx.adsl.inetia.pl [77.253.25.xxx)
    Received: from mmdodz.telecomitalia.it (hostxxx-123-static.23-87-b.business.telecomitalia.it [87.23.123.xxx])
    Received: from peiwjh.telecomitalia.it (hostxxx-171-dynamic.16-87-r.retail.telecomitalia.it [87.16.171.xxx])
    Received: from edny.telecomitalia.it (hostxxx-155-dynamic.40-79-r.retail.telecomitalia.it [79.40.155.xxx])

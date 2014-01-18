---
layout: post
title:  "Sender Policy Framework and ISP’s blocking port 25 seems problematic"
date:   2007-12-13 12:00:01
comments: true
---

EDIT: I found an article describing this scenario avaliable on the open SPF website, [here](http://old.openspf.org/mailflows.pdf)

Sender Policy Framework is the [RFC](http://tools.ietf.org/html/rfc4408) the defines an authorisation system for who is allowed to send email from a particular domain. It works by publishing TXT records in the root DNS for that domain that follow a correct syntax. This TXT record defines what servers are allowed to send mail from that domain. You can specify a network range, individual servers, hosts that are also listed as MX servers and so on. Its a good system that is slowly being adapted in an effort to reduce spam.

Another method that relies on the cooperation of ISPs is blocking outgoing port 25 outside of the ISP network. This means that infected zombie PC’s of DSL and cable subscribers wont be able to send mail out of the ISP network as this traffic will be blocked. To send legitimate mail, the user needs to setup their mail client to send mail via the ISPs SMTP server, which will then send it out to the rest of the world.

![1](/assets/posts/spf25outgoingblocked.png)

Therein lies a problem. We are combatting spam by blocking any outgoing traffic from port 25, but at the same time we are defining what servers can send mail from a particular domain. Say you have hundreds of remote users behind different ISPs, what do you do then? Do you manually add ALL of these servers to the allowed list? Unforunately there are many drawbacks of the SMTP protocol. It was drafted back in 1982 for a start, and really hasn’t seen any improvements to fighting spam over the years. The problem is, you cannot just change everything over in a day. It takes years and years to be adopted. Hopefully we can find patches to the current problems and ensure that any new standards have digital signing built in by default.

A few practical solutions to these problems would for the user to use a webmail client or perhaps VPN into the workplace (assuming we are talking a work environement) and use the company’s SMTP server.

Another technology called “Domain Keys” is simmilar to SPF in its operation to verify that the mail has been sent from a domain that is authorised to send. How it works is that the sent mail is digitally signed and the public key is avaliable through a DNS record. One small drawback is that this method requires inspection into the body of the message to get the domain key information, meaning more bandwidth is wasted on spam email.

SPF and DKIM only really addresses domain-wide authentication as to who (which servers) are allowed to send email. Anyone can technically send mail from anyone elses email address. There is no security as to who is allowed to send. There is no authentication stage for the user to send mail. For SMTP servers that are SASL aware and require a user name and password before the mail is relayed, only checks for a valid user. It does not check the sender of the email and make sure that the username and password entered is the same username that is authorised to send from that particular address. PGP (Pretty Good Privacy) and S/MIME can be implemented to sign mail to ensure that it did originate from the actual sender, but this is not widely adopted.
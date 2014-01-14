---
layout: default
title: RyanDoyle .net - My Internet House
---


About
=====
Hi I'm Ryan. I do things with computers. I like [networking](http://www.ietf.org/rfc/rfc0793.txt)
[protocols](http://tools.ietf.org/html/rfc2616), [GNU/Linux](https://www.kernel.org/)
[infastructure](https://puppetlabs.com) [as](http://babushka.me/) [code](http://www.meetup.com/Infrastructure-Coders),
[disposable](http://aws.amazon.com) [compute](https://github.com/dotcloud/docker), hacking in C and Ruby. That kind of stuff.

Blog Posts
==========
{% for post in site.posts %}
  {{ post.date | date_to_string }} - [{{ post.title }}]({{ post.url }})
{% endfor %}

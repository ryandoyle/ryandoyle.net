---
layout: post
title:  "Local web pages and Proxy Caching"
date:   2007-11-21 15:10:01
comments: true
---

Recently I encountered a seemingly random problem with external links in files hosted locally that would no longer use the proxy server to connect to the external site. Its a bit hard to explain exactly what I mean without breaking it down, so I will give an example.

1. Create a blank html page on your desktop and add
    <pre>&lt;html&gt;&lt;body&gt;&lt;a href=http://www.google.com&gt;GOOGLE&lt;/a&gt;&lt;/body&gt;&lt;/html&gt;</pre>
2. Make sure that you have your proxy settings configured in Internet Explorer.
3. Also make sure that you don’t have direct routed access to the Internet (IE: Without the proxy settings, you would not be able to connect)
4. Open up the html file you created in Internet Explorer. (So that the URL is “C:\Documents and Settings\Username\Desktop\htmlfile.html”)
5. Click on the google link and it should fail to load.

If it does work, congratulations, you don’t need to read on. If it doesn’t then continue. What it looks like is happening is that the proxy settings are cached and then not used when you go to an external site. Whilst reading more about proxy auto-config files (PAC files), I noticed some mention of this cached setting that is enabled in Internet Explorer.

I disabled it with a GPO, and afterwards, everything seemed to work properly. To get to it follow:

User Configuration > Administrative Templates > Windows Components > Disable Caching of Auto-Proxy scripts

and set it to enabled.
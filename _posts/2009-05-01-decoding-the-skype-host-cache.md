---
layout: post
title:  "Decoding the Skype Host Cache"
date:   2009-05-01 16:27:01
comments: true
---

The host cache in Skype keeps a database of peers that Skype talked to upon last running. A host cache is one of several bootstrapping technologies that peer-to-peer networks use to connect a peer into the overlay network.

The host cache is kept in the shared.xml file located in the users home directory. If you look at how the host cache is stored, it looks like a jumble of hex.

    ...41C8010500410502004C6E771C823B0001040002B981EDCE043
    B981EDCE04000400050041050200180818ADAFD40001040002BBA6
    8CCE040003BBA68CCE040004000500410502004A38D3323D990001
    040002B981EDCE040003B981EDCE04000400050041050200972FBC
    6464420001040002B981EDCE040003B981EDCE0400040005004105
    02005169EEF23F930001040002BD81EDCE040003BD81EDCE040004
    000500410502005C0F17B769F90001020002C481EDCE040003FA81
    EDCE040004000500410502005C4A838623360001020002BB81EDCE
    040003FA81EDCE04000400050041050200440AAA7D5EF100010200
    02BC81EDCE040003FA81EDCE040004000500410502003AAC048...

A pattern does start to emerge and I wrote a tool to extract the IP address and port of each peer listed in the host cache. It is written in perl and requires the XML::Simple module. You can [download the tool here](/assets/posts/skypecachedecode.pl).

I’ve only tested this with 2 different shared.xml files so let me know if you have any problems with it.


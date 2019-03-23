---
layout: post
title:  "Writing a PMDA for Performance Co-Pilot"
date:   2019-03-09 12:26:01
tags: [pcp, pmda, performance co pilot]
comments: true
---

In this post, we will go over writing a Performance Metrics Collection Agent (PMDA) for [Performance
Co-Pilot](https://pcp.io/) (PCP). PCP has a pluggable architecture and all metrics that exist within a PCP namespace
are implemented by PMDAs. 

We will implement a PMDA that reads [statistics](https://coreos.com/etcd/docs/latest/v2/api.html#statistics) from a
[etcd](https://coreos.com/etcd/) proxy server.

Lets get started!

# Prerequisites
---
## PCP development tools
You'll need PCP installed and depending on your operating system, you may need to install additional packages
for PMDA development support. I'm using Debian so these are the packages I need.

```bash
sudo apt install pcp libpcp-pmda3-dev python3-pcp
```

We will be using the PMDA debugging program, `dbpmda` to test our PMDA as we develop it. Make sure that is available too.
It should be install with PCP.
```bash
which dbpmda
```

# Hello PMDA
---
Let's start with a hello world example. Create a directory called `etcd` and inside that open a file called `pmdaetcd.python`. 
Python PMDAs need the `.python` extension, not `.py`. Paste the following in

```python
#!/usr/bin/env pmpython
from cpmapi import PM_TYPE_STRING, PM_INDOM_NULL, PM_SEM_INSTANT

from pcp.pmapi import pmUnits, pmContext
from pcp.pmda import PMDA, pmdaMetric


class EtcdPMDA(PMDA):

    def __init__(self, name, domain):
        super().__init__(name, domain)

        self.add_metric(name + '.demo', pmdaMetric(
            PMDA.pmid(0, 0),
            PM_TYPE_STRING,
            PM_INDOM_NULL,
            PM_SEM_INSTANT,
            pmUnits()
        ))

        self.set_fetch_callback(self.fetch_callback)
        self.set_user(pmContext.pmGetConfig('PCP_USER'))

    def fetch_callback(self, cluster, item, inst):
        return ['hello PMDA', 1]


if __name__ == '__main__':
    EtcdPMDA('etcd', 400).run()
``` 
## Breaking it down

Let's start with the shebang.
```python
#!/usr/bin/env pmpython
```
PCP still supports Python 2 and 3 as it is still distributed on Linux distributions that use Python 2 as a default. 
`pmpython` is a mechanism for finding the right version of Python that is in use. If you plan to ship your PMDA into the
mainline PCP codebase, make sure your code will run on both versions.

Next, lets look at the constructor.
```python
class EtcdPMDA(PMDA):
    def __init__(self, name, domain):
...
if __name__ == '__main__':
    EtcdPMDA('etcd', 400).run()

``` 
A PMDA is responsible for a namespace EG: `etcd.*`. We need to tell the PMDA what our namespace is. The other
argument is the `domain`. This is an internal identifier used in PCP. Check [stdpmid.pcp](https://github.com/performancecopilot/pcp/blob/master/src/pmns/stdpmid.pcp)
to find the next free ID. If we are shipping this into the PCP codebase, you'll need to add your ID here too.

We add metrics with the `self.add_metric()` method.
```python
        self.add_metric(name + '.demo', pmdaMetric(
            PMDA.pmid(0, 0),
            PM_TYPE_STRING,
            PM_INDOM_NULL,
            PM_SEM_INSTANT,
            pmUnits()
        ))
```
We register a name, `etcd.demo`, and then add metadata about the metric.
- [pmid](https://pcp.io/books/PCP_PG/html-single/#id5177529): This is part of the internal metric identifier and is 
unique for all metrics in the PMDA. The first number is the `cluster`, basically a grouping of related metrics. 
The second is the `item` which is the most specific. 
- type: It can be a `PM_TYPE_STRING`, `PM_TYPE_U32`, `PM_TYPE_64` etc...
- [indom](https://pcp.io/books/PCP_UAG/html-single/#id5188440): The instance domain that this metric belongs to.
We aren't using any instance domains at the moment but we will later on.
- sem (semantics): This describes how the metric represents the data. Although not useful with string metrics, we can
use this to mark the metric as a counter or gauge. The PCP client tools then know how to interpret the data and can 
then do automatic rate conversion.
- pmunits: We can add unit information like time, bytes or bytes per second. We use the default value here which means 
"no units".

As for fetching metrics, we define a _callback_. This is called when the PMDA is asked to provide metric values.
```python
    def fetch_callback(self, cluster, item, inst):
        return ['hello PMDA', 1]
```
Later on we will use the `cluster`, `item` and `inst` to return the correct metric value. The `1` in the return value
denotes success. If the fetching cannot be done, we return `0` with an error type.

## Sanity test
As a quick sanity test to make sure we don't have any syntax errors, we can
run the PMDA like any normal Python program. We have to run it via `sudo` because of the `self.set_user()` call.
```bash
chmod +x pmdaetcd.python
sudo ./pmdaetcd.python
# Ctrl+C
``` 
It should print some random garbage on the screen. PMDAs communicate via STDIN and STDOUT via a binary protocol. Although 
we can't do anything useful, this is still a good test to make sure the PMDA can at least start. To test actually fetching
 the metric, we will use the tool`dbpmda`.


## Testing with `dbpmda`
`dbpmda` is a command line test harness for PMDAs. It allows us to quickly iterate when developing the PMDA. 

Create a file called `pmns-for-testing` with the following content:
```
root {
    etcd    400:*:*
}
```

This will allow us to test the PMDA locally without having to install and register it with the global PCP namespace.
The number needs to match the domain we chose in the PMDA, `400` in our case.

Now run the following. 

```bash
cat<<EOF | sudo dbpmda -n pmns-for-testing
open pipe ./pmdaetcd.python
fetch etcd.demo
EOF
```
We have to run it as root because of the `self.set_user()` call. If you didn't want to run
this command as root, you could omit this line, just make sure to add it back before you ship the PMDA. 

If all went well, you should see the following output:
```
Start pmdaetcd.python PMDA: ./pmdaetcd.python
PMID(s): 400.0.0
pmResult dump from 0x5597b44f6910 timestamp: 0.000000 10:00:00.000 numpmid: 1
  400.0.0 (<noname>): numval: 1 valfmt: 1 vlist[]:
   value "hello PMDA"
```
## Testing by loading into PMCD
The PMDA can be loaded into PMCD to test via tools like `pminfo` and `pmchart`. The PMCD is the server that orchestrates
routing requests to the correct PMDA and handles communication with the clients.

First, we need to create an `Install` and `Remove` script. These scripts are shipped individually with each PMDA and is
the standard way that PCP installs and removes them.

`Install`
```bash
#!/bin/sh
. $PCP_DIR/etc/pcp.env
. $PCP_SHARE_DIR/lib/pmdaproc.sh

iam=etcd
domain=400
python_opt=true
daemon_opt=false

pmdaSetup
pmdaInstall
exit
```
`Remove`
```bash
#! /bin/sh
. $PCP_DIR/etc/pcp.env
. $PCP_SHARE_DIR/lib/pmdaproc.sh

iam=etcd

pmdaSetup
pmdaRemove
exit
```
Make the scripts executable
```bash
chmod +x Install Remove
```

PCP expects PMDAs to be located in a certain path (typically `/var/lib/pcp/pmdas/$pmda_name/`) so we will 
have to either move the `etcd/` directory into there and continue working  _or_ copy over the 
contents each time we want to update the PMDA. I'm going to copy the contents over.

```bash
sudo mkdir /var/lib/pcp/pmdas/etcd
sudo chown $USER /var/lib/pcp/pmdas/etcd
cp  pmdaetcd.python Install Remove /var/lib/pcp/pmdas/etcd/
cd /var/lib/pcp/pmdas/etcd/
sudo ./Install
```
You should get notified that metrics have appeared. Check it out:
```bash
pminfo -f etcd
```
## Next
Now that we have the basics of a PMDA working and an ability to test, lets implement more metrics exposed by Etcd.

# Extending the PMDA
---
## Etcd
Etcd has several API endpoints to get interesting statistics from. Our PMDA will expose these metrics through to PCP.

An example payload when calling the stats API looks like the following:

`curl http://127.0.0.1:2379/v2/stats/self`
```json
{
  "name": "etcd0",
  "id": "7931e79c0d8b47c5",
  "state": "StateFollower",
  "startTime": "2019-03-10T05:28:37.430724906Z",
  "leaderInfo": {
    "leader": "",
    "uptime": "8m33.5174986s",
    "startTime": "2019-03-10T05:28:37.430724906Z"
  },
  "recvAppendRequestCnt": 0,
  "sendAppendRequestCnt": 0
}
```
We will implement `name`, `id`, `state`, `recvAppendRequestCnt` and `sendAppendRequestCnt`

## Defining the metrics

We will add 5 `self.add_metric()` calls as well as implement fetching via the Python `requests` library. You may need this
library installed. On my platform, I installed it with `apt install python3-requests`.
```python
#!/usr/bin/env pmpython
from cpmapi import PM_TYPE_STRING, PM_INDOM_NULL, PM_SEM_INSTANT, PM_TYPE_U64, PM_SEM_COUNTER, PM_ERR_PMID, PM_ERR_AGAIN

import requests
from pcp.pmapi import pmUnits, pmContext
from pcp.pmda import PMDA, pmdaMetric


class EtcdPMDA(PMDA):

    def __init__(self, name, domain):
        super().__init__(name, domain)

        self.add_metric(name + '.name', pmdaMetric(
            PMDA.pmid(0, 0),
            PM_TYPE_STRING,
            PM_INDOM_NULL,
            PM_SEM_INSTANT,
            pmUnits()
        ))
        self.add_metric(name + '.id', pmdaMetric(
            PMDA.pmid(0, 1),
            PM_TYPE_STRING,
            PM_INDOM_NULL,
            PM_SEM_INSTANT,
            pmUnits()
        ))
        self.add_metric(name + '.state', pmdaMetric(
            PMDA.pmid(0, 2),
            PM_TYPE_STRING,
            PM_INDOM_NULL,
            PM_SEM_INSTANT,
            pmUnits()
        ))
        self.add_metric(name + '.recv_append_request', pmdaMetric(
            PMDA.pmid(0, 3),
            PM_TYPE_U64,
            PM_INDOM_NULL,
            PM_SEM_COUNTER,
            pmUnits()
        ))
        self.add_metric(name + '.send_append_request', pmdaMetric(
            PMDA.pmid(0, 4),
            PM_TYPE_U64,
            PM_INDOM_NULL,
            PM_SEM_COUNTER,
            pmUnits()
        ))

        self.set_fetch_callback(self.fetch_callback)
        self.set_user(pmContext.pmGetConfig('PCP_USER'))

    def fetch_callback(self, cluster, item, inst):
        if not cluster == 0:
            return [PM_ERR_PMID, 0]
        try:
            stats = requests.get('http://127.0.0.1:2379/v2/stats/self').json()
        except Exception:
            return [PM_ERR_AGAIN, 0]

        if item == 0:
            return [stats['name'], 1]
        if item == 1:
            return [stats['id'], 1]
        if item == 2:
            return [stats['state'], 1]
        if item == 3:
            return [stats['recvAppendRequestCnt'], 1]
        if item == 4:
            return [stats['sendAppendRequestCnt'], 1]
        return [PM_ERR_PMID, 0]


if __name__ == '__main__':
    EtcdPMDA('etcd', 400).run()
```

Lets test it with `dbpmda`

```bash
cat<<EOF | sudo dbpmda -n pmns-for-testing
open pipe ./pmdaetcd.python
fetch etcd.name
fetch etcd.id
fetch etcd.state
fetch etcd.recv_append_request
fetch etcd.send_append_request
EOF
```

### Typed metrics
We now use `PM_TYPE_U64` to define the data type of the counters. How did I know it is a U64? I had to check out
the source code of Etcd! It is important to get the types right, either through the documentation or even better
to look at the source code of where the metric is defined.

We also define this as a `PM_SEM_COUNTER`. PCP knows about the representation of numeric types so it is important
to get this information correct too. I've even omitted `...Cnt` from the metric names as we don't need need to encode
this information in the metric name. PCP knows if this is a counter or a gauge.

### Handling errors
In `fetch_callback()`, we handle two types of errors.

If we get a request for a `cluster` or `item` we don't know about, we return a `PM_ERR_PMID`. If there are any runtime
errors fetching the statistics, we return a `PM_ERR_AGAIN`. This indicates that the PMDA is unavailable and the client
should try again.

It is important to handle errors correctly in the PMDA. If an exception if thrown and not handled, _the PMDA will exit_.

# Instance domains
---
Instance domains add another dimension to the metric namespace. A metric can have zero or more _instances_ associated
with it. If I look up the `disk.dev.read` metric, each disk is listed at as instance.

```bash
$ pminfo -f disk.dev.read

disk.dev.read
    inst [0 or "sdb"] value 289
    inst [1 or "sda"] value 85578
    inst [2 or "sdc"] value 226
    inst [3 or "sdd"] value 89513
    inst [4 or "sde"] value 151
```

## Instance domains in etcd
If we look at the `/v2/stats/store` endpoint, there are metrics associated with successful and failed operations. 
`curl http://127.0.0.1:2379/v2/stats/store`
```json
{
  "getsSuccess": 2,
  "getsFail": 57,
  "setsSuccess": 0,
  "setsFail": 0,
  "deleteSuccess": 0,
  "deleteFail": 0,
  "updateSuccess": 0,
  "updateFail": 0,
  "createSuccess": 3,
  "createFail": 0,
  "compareAndSwapSuccess": 0,
  "compareAndSwapFail": 0,
  "compareAndDeleteSuccess": 0,
  "compareAndDeleteFail": 0,
  "expireCount": 0,
  "watchers": 0
}
```
We will define an instance domain for operations. That is, `gets`, `sets`, `deletes` etc... and then have a metric
`etcd.store.success` and `etcd.store.fail`. `expireCount` and `watchers` will be normal metrics without an instance domain.

## Adding instances to the PMDA
We will define the instance via `self.add_indom()`. Now, in the `self.fetch_callback()`, we will use the instance
as part of the metric lookup.

```python
#!/usr/bin/env pmpython
from cpmapi import PM_TYPE_STRING, PM_INDOM_NULL, PM_SEM_INSTANT, PM_TYPE_U64, PM_SEM_COUNTER, PM_ERR_PMID, PM_ERR_AGAIN

import requests
from pcp.pmapi import pmUnits, pmContext
from pcp.pmda import PMDA, pmdaMetric, pmdaInstid, pmdaIndom


class EtcdPMDA(PMDA):

    def __init__(self, name, domain):
        super().__init__(name, domain)

        self.add_metric(name + '.name', pmdaMetric(
            PMDA.pmid(0, 0),
            PM_TYPE_STRING,
            PM_INDOM_NULL,
            PM_SEM_INSTANT,
            pmUnits()
        ))
        self.add_metric(name + '.id', pmdaMetric(
            PMDA.pmid(0, 1),
            PM_TYPE_STRING,
            PM_INDOM_NULL,
            PM_SEM_INSTANT,
            pmUnits()
        ))
        self.add_metric(name + '.state', pmdaMetric(
            PMDA.pmid(0, 2),
            PM_TYPE_STRING,
            PM_INDOM_NULL,
            PM_SEM_INSTANT,
            pmUnits()
        ))
        self.add_metric(name + '.recv_append_request', pmdaMetric(
            PMDA.pmid(0, 3),
            PM_TYPE_U64,
            PM_INDOM_NULL,
            PM_SEM_COUNTER,
            pmUnits()
        ))
        self.add_metric(name + '.send_append_request', pmdaMetric(
            PMDA.pmid(0, 4),
            PM_TYPE_U64,
            PM_INDOM_NULL,
            PM_SEM_COUNTER,
            pmUnits()
        ))

        self.stats_operations_instances = [
            pmdaInstid(0, 'gets'),
            pmdaInstid(1, 'sets'),
            pmdaInstid(2, 'delete'),
            pmdaInstid(3, 'update'),
            pmdaInstid(4, 'create'),
            pmdaInstid(5, 'compareAndSwap'),
            pmdaInstid(6, 'compareAndDelete'),
        ]
        self.stats_operations_indom = self.indom(0)
        self.add_indom(pmdaIndom(self.stats_operations_indom, self.stats_operations_instances))

        self.add_metric(name + '.store.success', pmdaMetric(
            self.pmid(1, 0),
            PM_TYPE_U64,
            self.stats_operations_indom,
            PM_SEM_COUNTER,
            pmUnits()
        ))
        self.add_metric(name + '.store.fail', pmdaMetric(
            self.pmid(1, 1),
            PM_TYPE_U64,
            self.stats_operations_indom,
            PM_SEM_COUNTER,
            pmUnits()
        ))
        self.add_metric(name + '.store.expire', pmdaMetric(
            self.pmid(1, 2),
            PM_TYPE_U64,
            PM_INDOM_NULL,
            PM_SEM_COUNTER,
            pmUnits()
        ))
        self.add_metric(name + '.store.watchers', pmdaMetric(
            self.pmid(1, 3),
            PM_TYPE_U64,
            PM_INDOM_NULL,
            PM_SEM_INSTANT,
            pmUnits()
        ))

        self.set_fetch_callback(self.fetch_callback)
        self.set_user(pmContext.pmGetConfig('PCP_USER'))

    def fetch_callback(self, cluster, item, inst):
        if cluster == 0:
            try:
                stats = requests.get('http://127.0.0.1:2379/v2/stats/self').json()
            except Exception:
                return [PM_ERR_AGAIN, 0]

            if item == 0:
                return [stats['name'], 1]
            if item == 1:
                return [stats['id'], 1]
            if item == 2:
                return [stats['state'], 1]
            if item == 3:
                return [stats['recvAppendRequestCnt'], 1]
            if item == 4:
                return [stats['sendAppendRequestCnt'], 1]
        if cluster == 1:
            try:
                stats = requests.get('http://127.0.0.1:2379/v2/stats/store').json()
            except Exception:
                return [PM_ERR_AGAIN, 0]

            if item == 0:
                metric_name_in_json = self.inst_name_lookup(self.stats_operations_indom, inst) + 'Success'
                return [stats[metric_name_in_json], 1]
            if item == 1:
                metric_name_in_json = self.inst_name_lookup(self.stats_operations_indom, inst) + 'Fail'
                return [stats[metric_name_in_json], 1]
            if item == 2:
                return [stats['expireCount'], 1]
            if item == 3:
                return [stats['watchers'], 1]

        return [PM_ERR_PMID, 0]


if __name__ == '__main__':
    EtcdPMDA('etcd', 400).run()
```
Now use `dbpmda` to show the instances and new metrics we have defined.
```bash
cat<<EOF | sudo dbpmda -n pmns-for-testing
open pipe ./pmdaetcd.python
instance 400.0
fetch etcd.store.success
fetch etcd.store.fail
fetch etcd.store.watchers
fetch etcd.store.expire
EOF
```
We create an instance via `pmdaInstid()`. This takes the _internal_ instance identifier (a number) and the _external_
human-readable name. We then register these instances to be part of an instance domain via `self.add_indom()`

You can see in `fetch_callback()`, we now use the `inst` argument. There are a number
of ways you could fetch metrics using the instance identifier. For simplicity sake, we lookup the external name via
`self.inst_name_lookup()` and build the key name that is in the JSON structure.

# Further reading
---
There's some great documentation available in the [PCP Programmers Guide](https://pcp.io/books/PCP_PG/html/LE98072-PARENT.html) 
on writing PMDAs as well as the [simple PMDA](https://github.com/performancecopilot/pcp/tree/master/src/pmdas/simple)
showing off additional PMDA features.

The sources for all packaged PMDAs can be seen
[here](https://github.com/performancecopilot/pcp/tree/master/src/pmdas/) and show off other features such as dynamic
instance registration, caching, external configuration files, logging and label support.
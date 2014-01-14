---
layout: post
title:  "Stopping the runaway Bash train"
date:   2012-05-09 07:56:01
---

If Perl is the duct tape that holds the Internet together, Bash would have to be the duct tape that holds a Linux system together. Love it or hate it, you’re going to use shell programming at some stage on a Linux system. From init scripts that start daemons to scripts that run backups, Bash (or another *sh shell) is used everywhere. You could even build websites using Bash+CGI if you really wanted (My OpenWRT router does exactly this for its webUI)

With the simplicity of Bash programming comes some drawbacks – well perhaps more constraints than drawbacks. The one thing that I really dislike is the unexpected behaviour when things fail. By default Bash always fails open. That is, it continues to execute on failure of a command and it doesn’t stop. This is a **bad thing**. It turns into a runaway train that can only be stopped by frantically mashing **Ctrl** and **C** to send as many SIGINTs as possible before it destroys everything in its path.

So to program Bash safely, we need to do a LOT of error checking along the way. We constantly check exit codes of commands and then act accordingly. This method is not only error prone but makes programs longer that they need to be. We spend more time checking for errors that actually doing work.

Let’s look a some really simple sample code:

{% highlight bash %}
#!/bin/bash
echo "This command will probably fail"
ls /probably_doesnt_exist
echo "Script will keep executing"
{% endhighlight %}

Pretty basic. Lets put some error checking around it

{% highlight bash %}
#!/bin/bash
echo "This command will probably fail"
ls /probably_doesnt_exist
if [ $? -ne 0 ]; then
  echo "Above command failed. Getting our of here!"
  exit 1
fi
echo "Script will keep executing"
{% endhighlight %}

So that’s four lines to check a single command. What if we missed it? What if we were capturing the output and passing it to something destructive like an rm -rf?

There’s got to be a better way!
**And there is!**

Putting the brakes on the train
-------------------------------
We can change the default fail open to a fail safe using the bash built-in set -e. By putting that at the top of our script Bash will stop executing if any command fails.

{% highlight bash %}
#!/bin/bash
set -e

echo "This command will probably fail"
ls /probably_doesnt_exist
echo "Script will never get here!"
{% endhighlight %}

Simple? Yes. Flexible? Not so much. Sometimes we expect that there could be error conditions. Say perhaps a script that is used to check the status of a website and email us on failure. We might get a timeout error or SSL certificate errors and in such a case, Bash would kill the script straight after the failed execution.

Exception Handling
------------------
Lets grab a concept from modern languages and apply it to Bash - **Exception Handling**. That’s crazy! You can’t do that in Bash! Well, it’s not built-in but you can re-implement the same functionality.

{% highlight bash %}
#!/bin/bash
set -e
source exception.inc.sh

echo "This command will probably fail"
try ls /probably_doesnt_exist || catch 2,3
# will catch on an exit code of 2 or 3 (exit will be 2 in this case)
if $CAUGHT; then
    echo "If I got here, the exeption happened and was caught"
    echo "Run code in this block to deal with the caught exception"
fi

echo "Script will keep executing"

try ls /probably_doesnt_exist || catch 3 # Exit of 3 won't get caught
echo "Script will never get here!"
{% endhighlight %}

That doesn’t mean we wrap everything up in a **try**. For commands that we know might fail and we want to act on their exceptions (exit codes) we wrap it up in a try. For others, we get the bonus that a failure will stop execution of the script.

What are these try and catch functions anyway? They are just pretty basic functions that do some checking and setting of variables, making the syntax look a bit nicer inside our own Bash scripts.

{% highlight bash %}
#!/bin/bash
function try(){
    CAUGHT=false
    eval "$@"
    return $?
}

function catch(){
    # Arguments
    local RETURN="$?"
    CAUGHT=false
    # Cut up the comma passed exit codes into space separated
    local EXITS=`echo "$1" | sed 's/,/ /g'`
    local EXIT=
    # Check against each exit
    for EXIT in $EXITS; do
        if [ $EXIT = $RETURN ]; then
            CAUGHT=true
            break
        fi
    done
    # Work out if we caught the exception
    if $CAUGHT; then
        echo "Caught exception $RETURN"
        return 0
    else
        echo "Uncaught exception $RETURN, expecting $EXITS"
        return $RETURN
    fi
}
{% endhighlight %}

This is by no means the best implementation of try and catch functions. The use of the global $CAUGHT variable exists to simplify the use of the functions in our scripts. Don’t take these functions as the perfect example but do take it as a proof of concept for better Bash programming.

Final Thoughts
--------------
Whether we like it or not we’re going to be using Bash at some stage when administering a Linux system. We should apply the same good programming practices to these scripts as we do our other languages. At the very least using **set -e** at the top of our scripts will force us to address error conditions. With a fail safe mode to execute our scripts, we instantly create safer programs and stop the runaway Bash train.


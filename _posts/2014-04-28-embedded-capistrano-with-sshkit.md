---
layout: post
title:  "Embedded Capistrano with SSHKit"
date:   2014-04-28 20:18:01
comments: true
---

Capistrano is great for remote server automation over SSH but often I find myself only needing small parts from what the full
Capistrano suite has to offer. Starting with Capistrano 3, the SSH-part of Capistrano was split out into a separate project called
[SSHKit](https://github.com/capistrano/sshkit).

SSHKit comes with a neat DSL that we can easily embed in our Rakefiles. Lets go through an example of how I deploy my Jekyll-powered blog via Rake:

{% highlight ruby %}
# Rakefile
require 'yaml'
require 'sshkit'
require 'sshkit/dsl'

config = YAML.load_file('_config.yml')

deploy_server = config['deploy_server']
deploy_path = config['deploy_path']
deploy_user = config['deploy_user']

SSHKit::Backend::Netssh.configure do |ssh|
  ssh.ssh_options = {
      user: deploy_user,
      auth_methods: ['publickey']
  }
end

desc 'Deploy the site to production'
task :deploy do

  run_locally do
    execute 'jekyll', 'build'
  end

  on deploy_server do
    unless test "[ -d #{deploy_path} ]"
      as :root do
        execute 'mkdir', '-p', deploy_path
      end
    end
    unless test "[ `stat -c %U #{deploy_path}` = '#{deploy_user}']"
      as :root do
        execute 'chown', '-R', deploy_user, deploy_path
      end
    end
    upload! "_site/", deploy_path, recursive: true
  end

end
{% endhighlight %}

The `desc` and `task` are just plain Rake keywords. The rest of the DSL is SSHKit. Lets clean the code up and extract a `Blog` class:

{% highlight ruby %}
# Rakefile
require 'yaml'
require 'sshkit'
require 'sshkit/dsl'

config = YAML.load_file('_config.yml')

deploy_server = config['deploy_server']
deploy_path = config['deploy_path']
deploy_user = config['deploy_user']

SSHKit::Backend::Netssh.configure do |ssh|
  ssh.ssh_options = {
      user: deploy_user,
      auth_methods: ['publickey']
  }
end

class Blog
  def initialize(host, path, owner)
    @host = host
    @path = path
    @owner = owner
  end

  def deploy!
    compile
    upload
  end

  private

  def upload
    with_deploy_location_ready do
      @host.upload! "_site/", @path, recursive: true
    end
  end

  def with_deploy_location_ready
    create_deploy_path unless deploy_path_exists?
    chown_to_owner unless deploy_path_owned?
    yield
  end

  def deploy_path_exists?
    @host.test "[ -d #{@path} ]"
  end

  def create_deploy_path
    @host.as :root do
      @host.execute 'mkdir', '-p', @path
    end

  end

  def deploy_path_owned?
    @host.test "[ `stat -c %U #{@path}` = '#{@owner}']"
  end

  def chown_to_owner
    @host.as :root do
      @host.execute 'chown', '-R', @owner, @path
    end
  end

  def compile
    @host.run_locally { execute 'jekyll', 'build' }
  end

end

desc 'Deploy the site to production'
task :deploy do
  on deploy_server do
    Blog.new(self, deploy_path, deploy_user).deploy!
  end
end
{% endhighlight %}

That's pretty neat I think! For more documentation of SSHKit, have a look at its [EXAMPLES](https://github.com/capistrano/sshkit/blob/master/EXAMPLES.md).

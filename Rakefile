#!/usr/bin/env ruby
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


#!/usr/bin/env ruby
require 'yaml'
config = YAML.load_file('_config.yml')

desc 'Deploy the site to production'
task :deploy do
  system("jekyll build")
  system("rsync -a _site/* #{config['deploy_server']}:#{config['deploy_path']}")
end

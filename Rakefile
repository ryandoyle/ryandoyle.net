#!/usr/bin/env ruby
require 'yaml'
config = YAML.load_file('_config.yml')

task :deploy do
  system("rsync -av _site/* #{config['deploy_server']}:#{config['deploy_path']}")
end

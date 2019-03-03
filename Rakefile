#!/usr/bin/env ruby
require 'yaml'

desc 'deploy to S3'
task :deploy do
    sh 'bundle exec jekyll build'
    sh 'aws s3 sync  _site/ s3://ryandoyle.net/ --acl public-read'
end

desc 'serve website locally'
task :serve do
  sh 'bundle exec jekyll serve'
end

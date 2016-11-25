require 'opal'
require 'opal-browser'
require 'opal/rspec/rake_task'
require "bundler/gem_tasks"

Opal::RSpec::RakeTask.new(:default) do |server, task|
  task.pattern = 'spec/opal/**/*_spec.rb'
  server.append_path File.expand_path('../lib', __FILE__)
  server.source_map = true
  server.debug = true
end

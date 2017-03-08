require 'opal'
require 'opal/rspec/rake_task'
require "bundler/gem_tasks"

Opal::RSpec::RakeTask.new(:default) do |server, task|
  task.pattern = 'spec/opal/**/*_spec.rb'
  task.file = [ENV['FILE']] if ENV['FILE']
  server.append_path File.expand_path('../lib', __FILE__)
  server.source_map = true
  server.debug = true
end

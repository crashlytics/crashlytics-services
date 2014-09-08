#!/usr/bin/env rake

require 'rake/testtask'
require 'rspec/core/rake_task'
require 'bundler/gem_tasks'

RSpec::Core::RakeTask.new('spec')

desc 'Run tests'
task :default => :spec

namespace :services do
  desc 'Writes a YAML config to $FILE || the current directory'
  task :config do
    $:.unshift "#{ File.dirname(__FILE__) }/lib"
    require 'service'
    require 'yaml'

    file = ENV['FILE'] || File.join(File.dirname(__FILE__), 'service_hooks.yml')

    services = []
    Service.services.each do |identifier, svc|
      services << {
        :identifier => identifier,
        :name   => svc.title,
        :events => svc.handles,
        :schema => svc.schema,
        :pages  => svc.pages }
    end

    services.sort! { |x, y| x[:identifier] <=> y[:identifier] }
    output = YAML::dump(services)

    File.open(file, 'w') { |io| io << output }

    puts output
  end

  desc 'Copy service_hooks.yml to other projects'
  task :copy do
    file = ENV['FILE'] || File.join(File.dirname(__FILE__), 'service_hooks.yml')
    FileUtils.cp file, '/srv/crashlytics/config/www/service_hooks.yml'
    FileUtils.cp file, '/srv/crashlytics/config/daemon/service_hooks.yml'
  end
end

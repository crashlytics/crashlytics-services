# -*- encoding: utf-8 -*-
require File.expand_path('../lib/service/version', __FILE__)

Gem::Specification.new do |s|
  s.authors       = ['Crashlytics']
  s.email         = ['engineering@crashlytics.com']
  s.description   = %q{Crashlytics Service Hooks}
  s.summary       = %q{Integrations with third-party services}
  s.homepage      = 'https://github.com/crashlytics/gems/tree/master/service'

  s.files         = `git ls-files`.split($\)
  s.executables   = s.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  s.test_files    = s.files.grep(%r{^(test|spec|features)/})
  s.name          = 'crashlytics-service'
  s.require_paths = ['lib']
  s.version       = Service::VERSION

  s.add_dependency 'faraday', '0.8.1'
  s.add_dependency 'nokogiri', '1.5.5'
  s.add_dependency 'tinder', '1.9.1'
  s.add_dependency 'hipchat', '~> 0.7.0'
  s.add_dependency 'asana', '0.0.4'
  s.add_dependency 'octokit', '~> 2.0.0'

  s.add_development_dependency 'rspec', '2.11.0'
end

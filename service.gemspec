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

  s.add_dependency 'faraday'
  s.add_dependency 'nokogiri', '~> 1.5'

  # Note: we are stuck at tinder 1.9 until we can eliminate our dependency
  # on eventmachine 1.0.0.beta.4
  s.add_dependency 'tinder', '~> 1.9'

  # enforce consistency with worker pipeline version of eventmachine
  s.add_dependency 'eventmachine', '~> 1.0'
  s.add_dependency 'hipchat', '~> 1.4'
  s.add_dependency 'asana', '0.0.4'
  s.add_dependency 'octokit', '~> 3.7'
  s.add_dependency 'jira-ruby', '~> 0.1'
  s.add_dependency 'ruby-trello', '~> 1.1'
  s.add_dependency 'slack-notifier', '~> 1.0.0'

  s.add_development_dependency 'rake'
  s.add_development_dependency 'simplecov'
  s.add_development_dependency 'rspec', '~> 2.99'
  s.add_development_dependency 'webmock', '~> 1.20'
end

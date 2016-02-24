require 'rspec'
require 'service'
require 'json'
require 'nokogiri'

require 'support/matchers/service_schema_matchers'

RSpec.configure do |c|
  c.color = true
  c.formatter     = 'documentation'
end

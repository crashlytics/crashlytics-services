require 'rspec'
require 'service'
require 'json'
require 'nokogiri'

require 'support/matchers/service_schema_matchers'

RSpec.configure do |c|
  c.color = true
  c.formatter     = 'documentation'

  c.before(:type => :service) do
    allow_any_instance_of(Faraday::RestrictIPAddressesMiddleware).to receive(:denied?).and_return(false)
  end
end

module Service
  extend self

  # Public: Tracks the defined services.
  #
  # Returns a Hash of Service Identifier => Service Class.
  def services
    @services ||= {}
  end
end

require 'service/base'

Dir["#{File.dirname(__FILE__)}/services/**/*.rb"].each { |service| require "services/#{File.basename(service, '.rb')}" }

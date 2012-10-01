require 'timeout'
require 'faraday'

require 'service/attributes'
require 'service/http'
require 'service/schema'
require 'service/display'

module Service
  class Base
    class << self
      include Service::Attributes
      include Service::Schema
      include Service::Display

      attr_accessor :root, :env, :host
      %w(development test production staging).each do |m|
        define_method "#{m}?" do
          env == m
        end
      end

      # Public: Processes an incoming Service event.
      #
      # event   - A symbol identifying the event type.  Example: :new_issue
      # config  - A Hash with the configuration data for the Service.
      # payload - A Hash with the unique payload data for this Service instance.
      #
      # Returns a hash containing information which can be used to find the resource
      #   (eg. a ticket) created on the service, or nil.
      def receive(event, config, payload = nil, logger = nil)
        svc = new(event, config, payload, logger)

        Timeout.timeout(20, TimeoutError) do
          svc.send("receive_#{event}", config, payload)
        end
      end

      # Adds a subclassing service to the hash of available services
      #
      # Returns nothing.
      def inherited(svc)
        Service.services[svc.identifier] = svc
        super
      end

      # Gets the default events that this Service will handle.  This defines
      # the default event configuration when Hooks are created on Crashlytics.  By
      # default, Crashlytics Hooks will only send `new_issue` events.
      #
      # Returns an Array of Strings (or Symbols).
      def handles(*events)
        if events.empty?
          @default_events ||= [:issue_impact_change]
        else
          @default_events = events
        end
      end
    end

    # Logs a message.
    def log(msg)
      @logger.call msg
    end

    # Public: Gets the configuration data for this Service instance.
    #
    # Returns a Hash.
    attr_reader :config

    # Public: Gets the unique payload data for this Service instance.
    #
    # Returns a Hash.
    attr_reader :payload

    # Public: Gets the identifier for the Service's event.
    #
    # Returns a Symbol.
    attr_reader :event

    def initialize(event, config, payload = nil, logger = Proc.new {})
      @event   = event.to_sym
      @config  = config
      @payload = payload
      @logger  = logger
      @http    = nil
    end

    include Service::HTTP
  end
end

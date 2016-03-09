require 'timeout'

require 'service/attributes'
require 'service/http'
require 'service/schema'
require 'service/displayable_error'

module Service
  class Base
    class << self
      include Service::Attributes
      include Service::Schema

      # Public: Processes an incoming Service event.
      #
      # event   - A symbol identifying the event type.  Example: :new_issue
      # config  - A Hash with the configuration data for the Service.
      # payload - A Hash with the unique payload data for this Service instance.
      #
      # Returns a hash containing information which can be used to find the resource
      #   (eg. a ticket) created on the service, or nil.
      def receive(event, config, payload = nil, logger = nil)
        svc = new(config, logger)

        method = "receive_#{event}"
        if svc.respond_to?(method)
          if event == :verification
            svc.send(method)
          else
            svc.send(method, payload)
          end
        end
      end

      # Adds a subclassing service to the hash of available services
      #
      # Returns nothing.
      def inherited(svc)
        Service.services[svc.identifier] = svc
        super
      end

      def events_handled
        @events_handled ||= [:issue_impact_change]
      end

      # Gets / Sets the default events that this Service handles.
      def handles(*events)
        @events_handled = events
      end
    end

    # Logs a message.
    def log(msg)
      @logger.call msg
    end

    # raise an exception that will be displayed to the UI
    # preferred over allowing uncaught exceptions which will just be
    # rolled up into a generic error message
    def display_error(message)
      log(message)
      raise Service::DisplayableError.new(message)
    end

    # Public: Gets the configuration data for this Service instance.
    #
    # Returns a Hash.
    attr_reader :config

    def initialize(config, logger = Proc.new {})
      @config  = config
      @logger  = logger
    end

    # Note: this ordering is important
    include Service::HTTP
  end
end

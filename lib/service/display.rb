module Service
  module Display
    # This module allows the Service writer to control the presentation
    # of the configuration page in the application settings pane.

    # Public: Adds the given attributes to a page in the Settings UI.
    # Pages are displayed in the order they are defined in the Service class.
    #
    # Example:
    #
    #   class FooService < Service
    #     page "Title", [ :username, :password ]
    #   end
    #
    #   FooService.pages # => [ { :title => "Title", :attrs => [:username, :password] } ]
    #
    # title - title of the page, displayed above all the input fields and instructions.
    # attrs - array of attribute identifier symbols listing all the inputs for one page.
    def page(title, attrs)
      pages << { :title => title, :attrs => attrs }
    end

    # Public: Returns the services' pages array
    def pages
      @pages ||= []
    end

    # Public: getter and setter for services' logo URL string
    #
    # Example:
    #
    #   class FooService < Service
    #     logo "foo_logo.png"
    #   end
    #
    #   FooService.logo # => "foo_logo.png"
    #
    def logo(*args)
      args.empty? ? @logo || "" : @logo = args.first
    end
  end
end

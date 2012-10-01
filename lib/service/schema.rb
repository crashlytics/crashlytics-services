module Service
  module Schema
    # Public: Gets the current schema for the data attributes that this Service
    # expects. This schema is used to generate the Crashlytics Services admin
    # interface. The attributes type loosely to HTML input elements.
    #
    # Example:
    #
    #   class FooService < Service
    #     string :token, :label => "API Token"
    #   end
    #
    #   FooService.schema
    #   # => [[:string, :token, { :label => "API Token" }]]
    #
    # Returns an Array of [ Symbol attribute type, Symbol attribute name, { options hash } ] tuples.
    def schema
      @schema ||= []
    end

    # Public: Adds the given attributes as String attributes in the Service's
    # schema.
    #
    # Example:
    #
    #   class FooService < Service
    #     string :token, :label => "API Token", :placeholder => "Your API token",
    #                    :help => "You can find your token in..."
    #   end
    #
    #   FooService.schema
    #   # => [[:string, :token, { :label => "...", ... }]]
    #
    # identifier - attribute identifier
    # options    - a hash of options for the attribute, including :label,
    #              :placeholder, and :help (:help is a longer help text string)
    #
    # Returns nothing.
    def string(identifier, options={})
      add_to_schema :string, identifier, options
    end

    # Public: Adds the given attributes as Password attributes in the Service's
    # schema.
    #
    # Example:
    #
    #   class FooService < Service
    #     password :pass, :label => "Password", :help => "..."
    #   end
    #
    #   FooService.schema
    #   # => [[:password, :pass, { :label => "Password", :help => "..." } ]]
    #
    # identifier - attribute identifier
    # options    - a hash of options for the attribute, including :label,
    #              and :help (:help is a longer help text string)
    #
    # Returns nothing.
    def password(identifier, options={})
      add_to_schema :password, identifier, options
    end

    # Public: Adds the given attributes as Boolean attributes in the Service's
    # schema. This will display a checkbox in the UI.
    #
    # Example:
    #
    #   class FooService < Service
    #     boolean :mark_as_read, :label => "Mark as Read", :help => "..."
    #   end
    #
    #   FooService.schema
    #   # => [[:boolean, :mark_as_read, { :label => "Mark as Read", :help => "..." } ]]
    #
    # identifier - attribute identifier
    # options    - a hash of options for the attribute, including :label,
    #              :placeholder, and :help (:help is a longer help text string)
    #
    # Returns nothing.
    def boolean(identifier, options={})
      add_to_schema :boolean, identifier, options
    end

    # Adds the given attributes to the Service's data schema.
    #
    # type - A Symbol specifying the type: :string, :password, :boolean.
    # identifier - Symbol for attribute name.
    # options - options hash: { :label => "", :placeholder => "", :help => "" }
    #
    # Returns nothing.
    def add_to_schema(type, identifier, options)
      schema << { :type => type, :name => identifier.to_sym, :options => options }
    end
  end
end

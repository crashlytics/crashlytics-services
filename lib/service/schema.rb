module Service
  module Schema
    # Public: Gets the current schema for the data attributes that this Service
    # expects. This schema is used to generate the Crashlytics Services admin
    # interface. The attributes type loosely to HTML input elements.
    #
    # Example:
    #
    #   class FooService < Service
    #     string :username, :label => "Username"
    #   end
    #
    #   FooService.schema
    #   # => [[:string, :username, { :label => "Username" }]]
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
    #     string :username, :label => "Username", :placeholder => "Your username",
    #   end
    #
    #   FooService.schema
    #   # => [[:string, :username, { :label => "...", ... }]]
    #
    # identifier - attribute identifier
    # options    - a hash of options for the attribute, including :label,
    #              :placeholder, and :required
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
    #     password :pass, :label => "Password"
    #   end
    #
    #   FooService.schema
    #   # => [[:password, :pass, { :label => "Password", ... } ]]
    #
    # identifier - attribute identifier
    # options    - a hash of options for the attribute, including :label, :placeholder
    #              and :required
    #
    # Returns nothing.
    def password(identifier, options={})
      add_to_schema :password, identifier, options
    end

    # Public: Adds the given attributes as Checkbox attributes in the Service's
    # schema. This will display a checkbox in the UI.
    #
    # The value of this option will be the value specified in the "value" option.
    # Otherwise, no value will be present in the config for the given identifier.
    #
    # Example:
    #
    #   class FooService < Service
    #     checkbox :mark_as_read, :label => "Mark as Read", :placeholder => "..."
    #   end
    #
    #   FooService.schema
    #   # => [[:checkbox, :mark_as_read, { :label => "Mark as Read", :placeholder => "..." } ]]
    #
    # identifier - attribute identifier
    # options    - a hash of options for the attribute, including :label,
    #              :placeholder, and :required
    #
    # Returns nothing.
    def checkbox(identifier, options={})
      add_to_schema :checkbox, identifier, options
    end

    # Adds the given attributes to the Service's data schema.
    #
    # type - A Symbol specifying the type: :string, :password, :checkbox.
    # identifier - Symbol for attribute name.
    # options - options hash: { :label => "", :placeholder => "", :required => false }
    #
    # Returns nothing.
    def add_to_schema(type, identifier, options)
      schema << { :type => type, :name => identifier.to_sym, :options => options }
    end
  end
end

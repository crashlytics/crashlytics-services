module Service::Attributes
  # we use the same functions as getters and setters so that services'
  # schemas may be created in a clean, declarative manner. eg:
  #
  #   class Service::FooBar < Service::Base
  #     title "Foo Bar"
  #   end
  #
  #   FooBar.title # => "Foo Bar"
  #

  # Gets/sets the official title of this Service.  This is used in any
  # user-facing UI and documentation regarding the Service.
  #
  # Returns a String.
  def title(*args)
    args.empty? ? @title ||= name.sub(/.*:/, '') : @title = args.first
  end

  # Gets/sets the name that identifies this Service type.  This is a
  # short string that is used to uniquely identify the service internally.
  #
  # Returns a String.
  def identifier(*args)
    args.empty? ? @identifier ||= name.downcase.sub!(/.*:/, '') : @identifier = args.first
  end
end

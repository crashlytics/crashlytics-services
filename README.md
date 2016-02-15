# Crashlytics Service Integrations #

Simple, powerful, declarative integrations for popular third-party services.

![Screenshot](http://public.crashlytics.com.s3.amazonaws.com/fabric-services-readme-image.png)

### Rationale ###

Crashlytics users have oft-requested that we integrate with their favorite ticket-tracker or notification service. Given the sheer volume of awesome services out there, it was a daunting goal to try to satisfy everyone. Instead, we sought a more scalable approach:  open-sourced, event-driven integrations that anyone can add to!

### Giving Credit ###

GitHub leads the way in this space with their [Github Services](https://github.com/github/github-services) implementation and rather than reinvent the wheel, we thought it better to enhance it - and leverage an architecture that people are familiar with.

We've started with GitHub's approach and simplified and streamlined the implementation to fit better within Crashlytics' backend architecture and permit more customization of the front-end UI. As with the original, our additions are available under the Logical Awesome license and we're excited to see who takes this even further.

## How to Contribute ##
See [CONTRIBUTING.md](https://github.com/crashlytics/crashlytics-services/blob/master/CONTRIBUTING.md)

## Example ##

Services must inherit from `Service:Base` and begin by declaring their human-readable `title` and a url to their `logo`. Following these attributes, the service should declare its Schema and UI (see below).

The Service is responsible for acting in response to events it receives and for providing a facility to verify that it has been configured correctly.

```ruby
class Service::Foo < Service::Base
  title "Display Title"

  # input type methods take an identifier and optional options hash
  string   :url # [, :label => "label text", :placeholder => "https://example.com/foo/bar" ]
  password :api_key # [, :label => "label text"]
  checkbox  :checkbox_1 # [, :label => "" ]

  # Receives a config hash containing :identifier => value pairs for each input field
  # and a payload which for impact change events is a hash of data about the issue.
  #
  # Return true to indicate success.
  #
  # For failure or unexpected errors, it's recommended to raise here and let the integration
  # harness handle the error.  `nil` is not a recommended return value here as it is
  # just handled as a very generic error.
  def receive_issue_impact_change(config, issue)
    true
  end

  # Receives a config hash containing :identifier => value pairs for each input field.
  # Returns an array 2-tuple containing a boolean and a response message.
  # The boolean should be true if the data in the config was verified, otherwise false.
  #
  # You can also raise errors out of this method, but the response we return to users
  # will be very generic.  You should make every effort to handle known error scenarios
  # by rescuing from an exception and returning an appropriate [false, '<explanation>']
  # that will be played back to the user trying to set up an integration.
  def receive_verification
    # on success
    [true, "Successfully integrated!"]
  end
end
```

### Schema ###

The schema is defined in a declarative manner with Ruby class methods for each input type. Specify the unique identifer for the field and an optional options Hash.

Labels can include span, p, br, and anchor html tags.

### Functionality ###

A working service must respond to two methods: `receive_issue_impact_change` and `receive_verification`.

When a user is configuring a service, `receive_verification` will be called and passed in their configuration data. This method should confirm that the data is correct (eg. authenticate with the service) and return a 2-tuple with a boolean and a message.

When an issue's impact reaches the threshold set by the user, `receive_issue_impact_change` will be called with a hash of configuration data and a hash of data about the issue. Check out the other service implementations for examples of how to use this data.

Example issue hash:
```
{
  :title => 'issue title',
  :method => 'method name',
  :impact_level => 1,
  :impacted_devices_count => 1,
  :crashes_count => 1,
  :app => {
    :name => 'app name',
    :bundle_identifier => 'foo.bar.baz',
    :platform => 'ios'
  },
  :url => "http://foo.com/bar"
}
```

### Utilities ###

In a service, use `http_get` and `http_put` to make http requests. See `lib/service/http.rb` for documentation. We strongly recommend making all network requests under SSL. If you need to parse JSON, the standard ruby JSON module is available. For XML, the Nokogiri library is available.

### Environment ###

Services run on sandboxed servers under Ruby2.1.4. All configuration data entered by users is encrypted at rest using AES-256.

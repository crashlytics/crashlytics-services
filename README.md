# Crashlytics Service Integrations #

Simple, powerful, declarative integrations for popular third-party services.

![Screenshot](http://public.crashlytics.com.s3.amazonaws.com/fabric-services-readme-image.png)

### Rationale ###

Crashlytics users have oft-requested that we integrate with their favorite ticket-tracker or notification service. Given the sheer volume of awesome services out there, it was a daunting goal to try to satisfy everyone. Instead, we sought a more scalable approach: open-sourced, event-driven integrations that anyone can add to!

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

  # Receives a payload which for impact change events is a hash of data about the issue.
  #
  # Has access to a config hash containing :identifier => value pairs for each input field.
  #
  # Return value is ignored.
  #
  # For failure or unexpected errors, use the display_error helper to raise an exception
  # that will be displayed to the user.
  #
  # A helpful error message might include the unexpected HTTP response status code, or
  # a friendly explanation of an edge case that a customer could use to troubleshoot.
  #
  # Note: only brief messages are accepted, and due to bugs with formatting, please do not
  # use messages which include raw response body text.
  #
  def receive_issue_impact_change(payload)
    # response = http_post config[:project_url], <some-params>
    # if response.status == 200
    #   log("Successful!")
    # elsif response.status == 300
    #   display_error('It looks like your project was moved.')
    # else
    #   display_error('Something unexpected happened!')
    # end
  end

  # Has access to a config hash containing :identifier => value pairs for each input field.
  #
  # Return value is ignored.
  #
  # For failure or unexpected errors, use the display_error helper to raise an exception
  # that will be displayed to the user.
  #
  # A helpful error message might include the unexpected HTTP response status code, or
  # a friendly explanation of an edge case that a customer could use to troubleshoot.
  #
  def receive_verification
    # response = http_post config[:project_url], <some-params>
    #
    # if response.status == 200
    #   log("Successful!")
    # elsif response.status == 401
    #   display_error('Looks like you are not authorized!')
    # else
    #   display_error('Something unexpected happened!')
    # end
  end
end
```

### Schema ###

The schema is defined in a declarative manner with Ruby class methods for each input type. Specify the unique identifer for the field and an optional options Hash.

Labels can include span, p, br, and anchor html tags.

### Functionality ###

A working service must respond to two methods: `receive_issue_impact_change` and `receive_verification`.

Every service is initialized with config for its input params, which is made accessible as an instance method.

When a user is configuring a service, `receive_verification` will be called. This method should confirm that the config is correct (eg. authenticate with the service) and if not, it should use the display_error method to report problems to the UI.

When an issue's impact reaches the threshold set by the user, `receive_issue_impact_change` will be called hash of data about the issue. Check out the other service implementations for examples of how to use this data.

Example issue_impact payload:
```
{
  :event => 'issue_impact_change',
  :display_id => 1,
  :impact_level => 1,
  :method => 'SomeMethod',
  :title => 'SomeTitle',
  :impacted_devices_count => 0,
  :crashes_count => 0,
  :url => 'http://example.com',
  :app => {
    :name => 'Test',
    :bundle_identifier => 'io.fabric.test',
    :platform => 'platform'
  }
}
```

A service can also handle velocity alert reporting, in which case it should be configured as follows:

  handles :issue_impact_change, :issue_velocity_alert

When an issue is marked as a high velocity issue, `receive_issue_velocity_alert` will be called with a hash of data about the issue.  Check out the other service implementations for examples of how to use this data.

Example issue_velocity_alert payload:

```
{
  :event => 'issue_velocity_alert',
  :display_id => 1,
  :method => 'SomeMethod',
  :title => 'SomeTitle',
  :crash_percentage => 1.02,
  :version => '1.0 (1.1)',
  :url => 'http://example.com',
  :app => {
    :name => 'Test',
    :bundle_identifier => 'io.fabric.test',
    :platform => 'platform'
  }
}
```

### Utilities ###

In a service, use `http_get`, `http_post`, and `http_put` to make HTTP requests. See `lib/service/http.rb` for documentation. We strongly recommend making all network requests under SSL. If you need to parse JSON, the standard ruby JSON module is available. For XML, the Nokogiri library is available.

We do not support custom gem dependencies and require all new submissions to use our http library for communication.

### Environment ###

Services run on sandboxed servers under Ruby2.1.4. All configuration data entered by users is encrypted at rest using AES-256.

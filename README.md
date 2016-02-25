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
  # Return value is ignored.
  #
  # For failure or unexpected errors, use the display_error helper to raise an exception
  # that will be displayed to the user.
  #
  # A helpful error message might include the unexpected HTTP response status code, or
  # a friendly explanation of an edge case that a customer could use to troubleshoot.
  #
  # Note: only brief messages are accepted, and due to bugs with formatting, we can't accept
  # messages which include raw response body text.
  #
  def receive_issue_impact_change(config, issue)
    # response = http_post config[:project_url], <some-params>
    # if response.status == 200
    #   log("Successful!")
    # elsif response.status == 300
    #   display_error('It looks like your project was moved.')
    # else
    #   display_error('Something unexpected happened!')
    # end
  end

  # Receives a config hash containing :identifier => value pairs for each input field.
  #
  # Return value is ignored.

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

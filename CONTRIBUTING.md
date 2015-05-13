## How to Contribute ##

1. Fork the project.
1. Create a new file in `lib/services/<service-name>.rb`. See the full example in [README.md](https://github.com/crashlytics/crashlytics-services/blob/master/README.md) for details.
1. Add any external gems your code relies on to the gemspec, with specific version numbers.
1. Add an RSpec tests in `spec/services/<service-name>_spec.rb` so we know your code works!  Preferably cover at least the following four scenarios: `receive_verification` success, `receive_verification` failure, `receive_issue_impact_change` success, and `receive_issue_impact_change` failure.  We recommend using WebMock to verify edge cases.  See this [real live example](https://github.com/crashlytics/crashlytics-services/blob/master/spec/services/zohoprojects_spec.rb) for inspiration.  You can run the entire suite by doing `bundle install` and `bundle exec rake`.
1. Include a logo for the service in the `img/<service-name>.png` - max 155x45px on a transparent background.  This logo will appear in the email we send when someone enables your integration.
1. Include an all white version of your logo in the `img/<service-name>-mono.png` folder - max 280x45px on a transparent background.  This logo will appear in the Settings dashboard configuration page.
1. Send a pull request from your fork to [crashlytics/crashlytics-services](https://github.com/crashlytics/crashlytics-services)
1. We'll review the pull request and send feedback or just merge it in!

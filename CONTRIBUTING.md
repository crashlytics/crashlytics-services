## How to Contribute ##

### Phase 1: Pre-flight Check
1. Your service must be live and publicly accessible.  We don't accept submissions for services that are still under development.
1. Your service must be free, or you must provide us with an account that has access to the integration features.
  * Please contact support@fabric.io with a sample account we can use for testing.
  * Please also provide instructions on how to enable and access the feature if it is not turned on by default.

### Phase 2: Implementation
1. Fork the project.
1. Create a new file in `lib/services/<service-name>.rb`.
  * Trivialized documentation example: [README.md](https://github.com/crashlytics/crashlytics-services/blob/master/README.md)
  * A real integration implementation: [real live example](https://github.com/crashlytics/crashlytics-services/blob/master/lib/services/zohoprojects.rb)
1. If your integration must use a gem, add it to the gemspec, with specific version numbers.
  * If possible, we recommend you implement your integration using only the built-in HTTP functions instead of using gems.
  * Gems _can_ make integration with our backend infrastructure complex, so the more dependencies you bring in, the longer it may take us to finalize and deploy your integration.
  * Certain gems are not compatible with our backend (most notably, those that cannot be used within EventMachine), so please choose your dependencies sparingly.
1. Add an RSpec tests in `spec/services/<service-name>_spec.rb` so we know your code works! We recommend using WebMock to verify edge cases.  See this [real live example](https://github.com/crashlytics/crashlytics-services/blob/master/spec/services/zohoprojects_spec.rb) for inspiration.  You can run the entire suite by doing `bundle install` and `bundle exec rake`. Please cover at _minimum_ the following four scenarios:
  * `receive_verification` success
  * `receive_verification` failure
  * `receive_issue_impact_change` success
  * `receive_issue_impact_change` failure.
1. You must include a logo for the service in the `img/<service-name>.png`.  This logo will appear in the email we send when someone enables your integration.
  * max 155x45px on a transparent background
1. You must also include an all white version of your logo in the `img/<service-name>-mono.png` folder.  This logo will appear in the Settings dashboard configuration page.
  * max 280x45px on a transparent background
  * not including this version of the logo will require us to do additional work to include this integration and may result in significant delays in getting it shipped
1. Send a pull request from your fork to [crashlytics/crashlytics-services](https://github.com/crashlytics/crashlytics-services)
  * As part of the submission, please include a URL to your public API documentation that we can use while verifying the integration.
  * Please also include your Twitter handle and a headshot we can use to credit you [here](https://try.crashlytics.com/integrations/).

### Phase 3: Verification
1. Your tests must cover the minimum scenarios above, and must be passing.
1. We'll review the pull request and send feedback or just merge it in!

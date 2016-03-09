# How to Contribute #

## Bugs, Issues, Suggestions, Problems

Having problems with your integrations?  Have some ideas of how to make it even better?  Please share on our [Twitter Developers Forum](https://twittercommunity.com/c/fabric)

## Bugfixes

If you think you found a bug in one of our integrations, please open a PR with a failing test case that can reproduce the issue.  Even better: include a fix!

## Adding support for new service hooks

Want to integrate your service with Crashlytics?  This guide walks you through how to submit a PR for a new service integration.

### Phase 1: Pre-flight Check
1. Your service must be live and publicly accessible.  We don't accept submissions for services that are still under development.
1. Your service must be free, or you must provide us with an account that has access to the integration features.
  * Please contact support@fabric.io with a sample account we can use for testing.
  * Please also provide instructions on how to enable and access the feature if it is not turned on by default.

### Phase 2: Implementation
1. Fork the project.
1. Create a new file in `lib/services/<service-name>.rb`.
  * Trivialized documentation example: [README.md](https://github.com/crashlytics/crashlytics-services/blob/master/README.md)
  * A real integration implementation: [real live example](https://github.com/crashlytics/crashlytics-services/blob/master/lib/services/hipchat.rb)
1. We no longer accept submissions that have their own gem dependencies.
  * You must implement your integration using only the built-in HTTP functions.
1. Add RSpec tests in `spec/services/<service-name>_spec.rb` so we know your code works! We recommend using WebMock to verify edge cases.  See this [real live example](https://github.com/crashlytics/crashlytics-services/blob/master/spec/services/hipchat_spec.rb) for inspiration.  You can run the entire suite by doing `bundle install` and `bundle exec rake`. Please cover at _minimum_ the following six scenarios:
  * `receive_verification` success
  * `receive_verification` failure
  * `receive_issue_impact_change` success
  * `receive_issue_impact_change` failure.
  * `receive_issue_velocity_alert` success.
  * `receive_issue_velocity_alert` failure.
1. Your service must also be exercisable via `bin/test_service_hook`
1. You must include a logo for the service in the `img/<service-name>.png`.  This logo will appear in the email we send when someone enables your integration.
  * max 155x45px on a transparent background
1. You must also include an all white version of your logo in the `img/<service-name>-mono.png` folder.  This logo will appear in the Settings dashboard configuration page.
  * max 280x45px on a transparent background
  * not including this version of the logo will require us to do additional work to include this integration and may result in significant delays in getting it shipped
1. Send a pull request from your fork to [crashlytics/crashlytics-services](https://github.com/crashlytics/crashlytics-services)
  * As part of the submission, please include a URL to your public API documentation that we can use while verifying the integration.
  * Please also include your Twitter handle and a headshot we can use to credit you [here](https://try.crashlytics.com/integrations/).

### Phase 3: Verification
1. For us to test and ship your integration, your tests must cover the minimum scenarios above, actually exercise your code, and be passing.
1. We will need to be able to use a live account to verify your integration from our test environment.
1. When we get started working on your integration, we will close your original PR and open a new internal one for any final changes (helptext changes, style tweaks, etc.).
1. Once we are able to successfully confirm the integration works, we will merge our internal PR and ship it.

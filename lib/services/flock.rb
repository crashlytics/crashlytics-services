class Service::Flock < Service::Base
  title 'Flock'

  string :url, :placeholder => 'Flock Webhook URL',
                 :label => 'Go to the <a href="https://apps.flock.co/crashlytics">Flock App Store</a> and install the Crashlytics app. <br />' \
                    'Generate the Flock Webhook URL and paste it below:'

  def receive_verification
    if app_store_flock_url?
      response = post_to_flock(:event => 'verification', :payload_type => 'none')
    elsif api_flock_url?
      response = post_to_flock(:text => 'Successfully configured Flock service hook with Crashlytics')
    else
      display_error("#{self.class.title} verification failed - URL is not an expected format.")
    end

    if response.success?
      log('verification successful')
    else
      display_error "#{self.class.title} verification failed - #{error_response_details(response)}"
    end
  end

  def receive_issue_impact_change(payload)
    if app_store_flock_url?
      response = post_to_flock(payload)
    elsif api_flock_url?
      response = post_to_flock(:text => extract_flock_message(payload))
    else
      display_error("#{self.class.title} issue impact change failed - URL is not an expected format.")
    end

    if response.success?
      log('issue_impact_change successful')
    else
      display_error "#{self.class.title} issue impact change failed - #{error_response_details(response)}"
    end
  end

  def extract_flock_message(payload)
    "#{payload[:app][:name]} crashed at #{payload[:title]}\n" +
    "Method: #{payload[:method]}\n" +
    "Number of crashes: #{payload[:crashes_count]}\n" +
    "Number of impacted devices: #{payload[:impacted_devices_count]}\n" +
    "More information: #{payload[:url]}"
  end

  def app_store_flock_url?
    config[:url].start_with?('https://apps.flock')
  end

  def api_flock_url?
    config[:url].start_with?('https://api.flock')
  end

  def post_to_flock(payload)
    http_post(config[:url]) do |request|
      request.headers['Content-Type'] = 'application/json'
      request.body = payload.to_json
    end
  end
end


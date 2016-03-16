class Service::Flock < Service::Base
  title 'Flock'

  string :url, :placeholder => 'Incoming Webhook URL',
                 :label => 'Flock Incoming Webhook URL. <br />' \
                   'To create an incoming webhook, go to your Flock admin panel and switch to "Webhooks" tab'

  def receive_verification
    response = post_to_flock('Successfully configured Flock service hook with Crashlytics')
    if response.success?
      log('verification successful')
    else
      display_error "#{self.class.title} verification failed - #{error_response_details(response)}"
    end
  end

  def receive_issue_impact_change(payload)
    message = extract_flock_message(payload)
    response = post_to_flock(message)
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

  def post_to_flock(message)
    body = { :text => message }

    http_post(config[:url]) do |request|
      request.headers['Content-Type'] = 'application/json'
      request.body = body.to_json
    end
  end
end


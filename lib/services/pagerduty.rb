class Service::Pagerduty < Service::Base
  title 'Pagerduty'

  password :api_key, :label => 'Create a new Pagerduty service using the Generic API, then paste the API key here.',
    :placeholder => 'Pagerduty API key'

  # Create an issue on Pagerduty
  def receive_issue_impact_change(payload)
    resp = post_event('issue_impact_change', 'issue', payload)
    if resp.success?
      log('issue_impact_change successful')
    else
      display_error("Pagerduty issue impact change failed - #{error_response_details(resp)}")
    end
  end

  def receive_verification
    resp = post_event('verification', 'none', nil)
    if resp.success?
      log('verification successful')
    else
      display_error("Pagerduty verification failed - #{error_response_details(resp)}")
    end
  end

  private
  def post_event(event, payload_type, payload)
    url = 'https://events.pagerduty.com/generic/2010-04-15/create_event.json'
    issue_description = ""
    issue_details = {}

    if event == 'verification'
      issue_description = '[Crashlytics] Pagerduty settings verified!'
    elsif event == 'issue_impact_change'
      issue_description = "[Crashlytics] Impact level #{payload[:impact_level]} issue in #{payload[:app][:name]} (#{payload[:app][:bundle_identifier]})\r\n#{payload[:url]}"
      issue_details = {
        'impacted devices' => payload[:impacted_devices_count],
        'crashes' => payload[:crashes_count],
      }
    end

    post_body = {
      'service_key' => config[:api_key],
      'event_type' => 'trigger',
      'description' => issue_description,
      'details' => issue_details
    }

    resp = http_post url do |req|
      req.headers['Content-Type'] = 'application/json'
      req.body                    = post_body.to_json
    end
    resp
  end
end

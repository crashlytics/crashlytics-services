class Service::Appaloosa < Service::Base
  title "Appaloosa"
  string :url, :placeholder => 'Incoming Webhook URL',
         :label => 'Your Appaloosa Incoming Webhook URL. <br />' \
                   'You can find your incoming webhook url under the issues section in application details.'

  # Create an issue
  def receive_issue_impact_change(payload)
    response = post_event(config[:url], 'issue_impact_change', 'issue', payload)
    if successful_response?(response)
      true
    else
      raise "Appaloosa WebHook issue create failed - #{error_response_details(response)}"
    end
  end

  def receive_verification
    success = [true,  "Successfully sent a message to Appaloosa"]
    failure = [false, "Could not send a message to Appaloosa"]
    response = post_event(config[:url], 'verification', 'none', nil)
    if successful_response?(response)
      success
    else
      failure
    end
  rescue => e
    log "Received a verification error in Appaloosa: (url=#{config[:url]}) #{e}"
    failure
  end

  private
  # Post an event string to a url with a payload hash
  # Returns true if the response code is anything 2xx, else false
  def post_event(url, event, payload_type, payload)
    body = {
      :event        => event,
      :payload_type => payload_type }
    body[:payload]  =  payload if payload

    http_post(url) do |req|
      req.headers['Content-Type'] = 'application/json'
      req.body                    = body.to_json
      req.params['verification']  = 1 if event == 'verification'
    end
  end
end

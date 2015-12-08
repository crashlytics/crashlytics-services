class Service::Appaloosa < Service::Base
  title "Appaloosa"
  string :url, :placeholder => 'Incoming Webhook URL',
         :label => 'Your Appaloosa Incoming Webhook URL. <br />' \
                   'You can find your incoming webhook url under the issues section in application details.'
  page "URL", [ :url ]

  # Create an issue
  def receive_issue_impact_change(config, payload)
    response = post_event(config[:url], 'issue_impact_change', 'issue', payload)
    if successful_response?(response)
      # return :no_resource if we don't have a resource identifier to save
      :no_resource
    else
      raise "Appaloosa WebHook issue create failed - #{error_response_details(response)}"
    end
  end

  def receive_verification(config, _)
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

  def successful_response?(response)
    (200..299).include?(response.status)
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

  def error_response_details(response)
    status_code_info = "HTTP status code: #{response.status}"
    if discard_body?(response.body)
      status_code_info
    else
      "#{status_code_info}, body: #{response.body}"
    end
  end

  def discard_body?(body)
    body =~ /!DOCTYPE/
  end
end

class Service::Moxtra < Service::Base
  title "Moxtra"
  string :url, :placeholder => 'Incoming Webhook URL',
         :label => 'Your Moxtra Incoming Webhook URL. <br />' \
                   'You can find your incoming webhook url under integrations in your Moxtra account.'
  page "URL", [ :url ]

  # Create an issue
  def receive_issue_impact_change(config, payload)
    response = post_event(config[:url], 'issue_impact_change', 'issue', payload)
    if successful_response?(response)
      # return :no_resource if we don't have a resource identifier to save
      :no_resource
    else
      raise "Moxtra WebHook issue create failed: HTTP status code: #{response.status}, body: #{response.body}"
    end
  end

  def receive_verification(config, _)
    success = [true,  "Successfully sent a message to Moxtra binder"]
    failure = [false, "Could not send a message to Moxtra binder"]
    response = post_event(config[:url], 'verification', 'none', nil)
    if successful_response?(response)
      success
    else
      failure
    end
  rescue => e
    log "Received a verification error in Moxtra: (url=#{config[:url]}) #{e}"
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
end

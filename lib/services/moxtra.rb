class Service::Moxtra < Service::Base
  title "Moxtra"
  string :url, :placeholder => 'Incoming Webhook URL',
         :label => 'Your Moxtra Incoming Webhook URL. <br />' \
                   'You can find your incoming webhook url under integrations in your Moxtra account.'

  # Create an issue
  def receive_issue_impact_change(payload)
    response = post_event(config[:url], 'issue_impact_change', 'issue', payload)
    if response.success?
      log('issue_impact_change successful')
    else
      display_error("Moxtra WebHook issue create failed - #{error_response_details(response)}")
    end
  end

  def receive_verification
    response = post_event(config[:url], 'verification', 'none', nil)
    if response.success?
      log('verification successful')
    else
      display_error('Could not send a message to Moxtra binder')
    end
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

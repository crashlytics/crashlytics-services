class Service::Hall < Service::Base
  title 'Hall'

  string :group_token, :placeholder => 'API Token',
         :label => 'Your Hall Group API Token. <br />' \
                   'You can retrieve your Group API Token ' \
                   '<a href="https://hall.com/docs/integrations/crashlytics/">here</a>.'

  page 'Group API Token', [:group_token]

  # Create an issue
  def receive_issue_impact_change(config, payload)
    response = send_hall_message(config, payload)
    if successful_response?(response)
      :no_resource
    else
      raise "Failed to send Hall message. HTTP status code: #{response.status}, body: #{response.body}"
    end
  end

  def receive_verification(config, _)
    success = [true,  "Successfully verified Group API Token"]
    failure = [false, "Oops! Please check your Group API Token."]
    response = verify_hall_service(config)
    if successful_response?(response)
      success
    else
      failure
    end
  rescue => e
    log "Rescued a verification error in Hall for Group API Token: '#{config[:group_token]}' #{e}"
    failure
  end

  private
  # Post an event string to a url with a payload hash
  # Returns true if the response code is anything 2xx, else false
  def post_event(config, event, payload_type, payload)
    url = "https://hall.com/api/1/services/crashlytics/#{config[:group_token]}"

    body = {
      :event        => event,
      :payload_type => payload_type }
    body[:payload]  =  payload if payload

    http_post url do |req|
      req.headers['Content-Type'] = 'application/json'
      req.body                    = body.to_json
      req.params['verification']  = 1 if event == 'verification'
    end
  end

  def successful_response?(response)
    (200..299).include?(response.status)
  end

  def verify_hall_service(config)
    post_event(config, 'verification', 'issue', nil)
  end

  def send_hall_message(config, msg)
    post_event(config, 'issue_impact_change', 'issue', msg)
  end
end

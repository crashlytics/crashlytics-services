class Service::WebHook < Service::Base
  title 'WebHook'
  string :url, :placeholder => 'https://[user:pass@]acme.com?key=123',
         :label => 'Enter the URL to receive our JSON data POST. ' \
                   '(<a href="http://support.crashlytics.com/knowledgebase/articles/102391-how-do-i-configure-a-custom-web-hook" target="_blank">more info</a>)'

  def receive_issue_impact_change(payload)
    response = post_event(config[:url], 'issue_impact_change', 'issue', payload)
    if response.success?
      log('issue_impact_change successful')
    else
      display_error "#{self.class.title} issue impact change failed - #{error_response_details(response)}"
    end
  end

  def receive_verification
    response = post_event(config[:url], 'verification', 'none', nil)
    if response.success?
      log('verification successful')
    else
      display_error("#{self.class.title} verification failed - #{error_response_details(response)}")
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

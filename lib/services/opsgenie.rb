class Service::OpsGenie < Service::Base
  title "OpsGenie"

  password :api_key, :label => 'Add a new Crashlytics integration at https://www.opsgenie.com/integration?add=Crashlytics and paste the integration\'s API key here.',
    :placeholder => 'OpsGenie API key'

  def receive_issue_impact_change(payload)
    body = {
      :payload        => payload,
      :event          => 'issue_impact_change'
    }
    resp = post_to_opsgenie(config, body)
    if resp.success?
      log 'issue_impact_change successful'
    else
      display_error "OpsGenie issue creation failed - #{error_response_details(resp)}"
    end
  end

  def receive_verification
    body = {
      :event        => 'verification'
    }
    resp =  post_to_opsgenie(config, body)
    if resp.success?
      log('verification successful')
    else
      log "Receive verification failed, API key: #{config[:api_key]}, OpsGenie response: #{resp[:status]}"
      display_error 'Couldn\'t verify OpsGenie settings; please check your API key.'
    end
  end

  def post_to_opsgenie(config, body)
    http_post(url) do |req|
      req.body = body.to_json
      req.params['apiKey'] = config[:api_key]
    end
  end

  def url
    'https://api.opsgenie.com/v1/json/crashlytics'
  end
end

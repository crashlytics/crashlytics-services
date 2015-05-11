class Service::OpsGenie < Service::Base
  title "OpsGenie"

  string :api_key, :label => 'Add a new Crashlytics integration at https://www.opsgenie.com/integration?add=Crashlytics and paste the integration\'s API key here.',
    :placeholder => 'OpsGenie API key'
  page "API Key", [:api_key]

  def receive_issue_impact_change(config, payload)
    body = {
      :payload        => payload,
      :event          => 'issue_impact_change'
    }
    resp = post_to_opsgenie(config, body)
    raise "OpsGenie issue creation failed: #{resp.status} - #{resp.body}" unless resp.success?
    log "Issue impact change successfully submitted to OpsGenie: #{resp[:status]}, payload: #{payload}"
    :no_resource
  end

  def receive_verification(config, _)
    body = {
      :event        => 'verification'
    }
    resp =  post_to_opsgenie(config, body)
    if resp.success?
      [true,  'Successfully verified OpsGenie settings']
    else
      log "Receive verification failed, API key: #{config[:api_key]}, OpsGenie response: #{resp[:status]}"
      [false, 'Couldn\'t verify OpsGenie settings; please check your API key.']
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

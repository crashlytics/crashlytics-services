class Service::FogBugz < Service::Base
  title 'FogBugz'

  string :project_url, :placeholder => "https://yourproject.fogbugz.com",
         :label => 'URL to your FogBugz project:'
  password :api_token, :placeholder => 'API Token',
           :label => 'Your FogBugz API Token.'

  # Create an issue
  def receive_issue_impact_change(payload)
    http.ssl[:verify] = true

    post_body = {
      :sTitle => "#{payload[:title]} [Crashlytics]",
      :sEvent => build_case_event(payload)
    }

    response = http_post fogbugz_url(:cmd => 'new') do |req|
      req.body = post_body
    end

    fogbugz_case, error = parse_response(response, 'response/case')

    if fogbugz_case && !error
      log('issue_impact_change successful')
    else
      log("issue_impact_change failure: #{error}")
      display_error("Could not create FogBugz case")
    end
  end

  def receive_verification
    http.ssl[:verify] = true

    response = http_get fogbugz_url(:cmd => 'listProjects')

    project, error = parse_response(response, 'response/projects')

    if project && !error
      log('verification successful')
    else
      log "verification failure: #{error}"
      display_error('Oops! Please check your API key again.')
    end
  end

  private
  def fogbugz_url(params={})
    query_params = params.map { |k,v| "#{k}=#{v}" }.join('&')

    "#{config[:project_url]}/api.asp?token=#{config[:api_token]}&#{query_params}"
  end

  def build_case_event(payload)
    users_text = if payload[:impacted_devices_count] == 1
      'This issue is affecting at least 1 user who has crashed '
    else
      "This issue is affecting at least #{payload[:impacted_devices_count]} users who have crashed "
    end

    crashes_text = if payload[:crashes_count] == 1
      'at least 1 time.'
    else
      "at least #{payload[:crashes_count]} times."
    end

<<-EOT
Crashlytics detected a new issue.
#{payload[:title]} in #{payload[:method]}

#{users_text}#{crashes_text}

More information: #{payload[:url]}
EOT
  end

  def parse_response(response, subject_selector)
    xml = Nokogiri.XML(response.body)
    error = xml.at('response/error')
    subject = xml.at(subject_selector)
    [subject, error]
  end
end

class Service::HipChat < Service::Base
  title 'HipChat'
  handles :issue_impact_change, :issue_velocity_alert

  password :api_token, :placeholder => 'API Token',
           :label => 'Your HipChat API Token. <br />' \
                     'You can create an API v1 notification token ' \
                     '<a href="https://www.hipchat.com/admin/api">here</a>.'
  checkbox :v2, :label => 'Is this an API v2 token?'
  string :room, :placeholder => 'Room ID or Name', :label => 'The ID or name of the room.'
  checkbox :notify, :label => 'Should a notification be triggered for people in the room?'
  string :url, :placeholder => 'https://api.hipchat.com', :label => 'The URL of the HipChat server.', :required => false

  def receive_verification
    send_message(verification_message, :color => 'green')
    log_message("verification successful")
  end

  def receive_issue_impact_change(payload)
    message_content = format_issue_message(payload, "Just reached impact level #{payload[:impact_level]}")
    send_message(message_content, :color => 'yellow')
    log_message("issue_impact_change successful")
  end

  def receive_issue_velocity_alert(payload)
    message_content = format_issue_message(payload, "Velocity Alert! Crashing #{payload[:crash_percentage]}% of all sessions in the past hour on version #{payload[:version]}")
    send_message(message_content, :color => 'red')
    log_message("issue_velocity_alert successful")
  end

  private

  def v2?
    ['true', true].include?(config[:v2])
  end

  def notify?
    ['true', true].include?(config[:notify])
  end

  def log_prefix
    v2? ? 'v2' : 'v1'
  end

  def log_message(message)
    log("#{log_prefix} #{message}")
  end

  def verification_message
    'Boom! Crashlytics notifications have been added.  ' \
    '<a href="http://support.crashlytics.com/knowledgebase/articles/349341-what-kind-of-third-party-integrations-does-crashly">' \
    'Click here for more info</a>.'
  end

  def format_issue_message(payload, extra_explanation)
    "<a href=#{payload[:url].to_s}>" \
    "[#{payload[:app][:name]} - #{payload[:app][:bundle_identifier]}] Issue ##{payload[:display_id]}: " \
    "#{payload[:title] } #{payload[:method]}" \
    "</a> - #{extra_explanation}"
  end

  def send_message(message, extra_options = {})
    room = config[:room]
    server_url = (config[:url].nil? || config[:url].empty?) ? 'https://api.hipchat.com' : config[:url]

    body = {
      "room_id" => room,
      "from" => "Crashlytics",
      "message" => message,
      "message_format" => "html",
      "color" => extra_options[:color] || "yellow",
      "notify" => notify?
    }

    # Configure the request based on the HipChat api version
    api_url, content_type, body = if v2?
      [
        "#{server_url}/v2/room/#{URI.encode(room)}/notification",
        'application/json',
        body.to_json
      ]
    else
      body['notify'] = notify? ? 1 : 0
      [
        "#{server_url}/v1/rooms/message",
        'application/x-www-form-urlencoded',
        body
      ]
    end

    resp = http_post(api_url, body) do |req|
      req.params['auth_token'] = config[:api_token]
      req.headers['Content-Type'] = content_type
      req.headers['Accept'] = 'application/json'
    end

    if !resp.success?
      display_error "Could not send a message to room #{ config[:room]} - #{error_response_details(resp)}"
    end
  end
end

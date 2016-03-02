class Service::HipChat < Service::Base
  title 'HipChat'

  password :api_token, :placeholder => 'API Token',
           :label => 'Your HipChat API Token. <br />' \
                     'You can create an API v1 notification token ' \
                     '<a href="https://www.hipchat.com/admin/api">here</a>.'
  checkbox :v2, :label => 'Is this an API v2 token?'
  string :room, :placeholder => 'Room ID or Name', :label => 'The ID or name of the room.'
  checkbox :notify, :label => 'Should a notification be triggered for people in the room?'
  string :url, :placeholder => 'https://api.hipchat.com', :label => 'The URL of the HipChat server.', :required => false

  def receive_verification
    send_message(config, verification_message)
    log('verification successful')
  end

  def receive_issue_impact_change(payload)
    send_message(config, format_issue_impact_change_message(payload))
    log('issue_impact_change successful')
  end

  private

  def verification_message
    'Boom! Crashlytics issue change notifications have been added.  ' \
    '<a href="http://support.crashlytics.com/knowledgebase/articles/349341-what-kind-of-third-party-integrations-does-crashly">' \
    'Click here for more info</a>.'
  end

  def format_issue_impact_change_message(payload)
    "<a href=#{ payload[:url].to_s }>" \
    "[#{ payload[:app][:name] } - #{ payload[:app][:bundle_identifier] }] Issue ##{ payload[:display_id] }: " \
    "#{ payload[:title] } #{ payload[:method] }" \
    '</a>'
  end

  def send_message(config, message)
    token = config[:api_token]
    room = config[:room]
    notify = config[:notify] ? true : false
    server_url = (config[:url].nil? || config[:url].empty?) ? 'https://api.hipchat.com' : config[:url]

    body = {
      "room_id" => room,
      "from" => "Crashlytics",
      "message" => message,
      "message_format" => "html",
      "color" => "yellow",
      "notify" => notify
    }

    # Configure the request based on the HipChat api version
    api_url, content_type, body = if config[:v2]
      [
        "#{server_url}/v2/room/#{URI.encode(room)}/notification",
        'application/json',
        body.to_json
      ]
    else
      body['notify'] = notify ? 1 : 0
      [
        "#{server_url}/v1/rooms/message",
        'application/x-www-form-urlencoded',
        body
      ]
    end

    resp = http_post(api_url, body) do |req|
      req.params['auth_token'] = token
      req.headers['Content-Type'] = content_type
      req.headers['Accept'] = 'application/json'
    end

    if !resp.success?
      display_error "Could not send a message to room #{ config[:room]} - #{error_response_details(resp)}"
    end
  end
end

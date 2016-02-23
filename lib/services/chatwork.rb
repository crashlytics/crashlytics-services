require 'json'

class Service::ChatWork < Service::Base
  title 'ChatWork'

  string :api_token, :placeholder => 'API Token',
         :label => 'Your ChatWork API Token. <br />' \
                   'You can create an API Token ' \
                   '<a href="https://www.chatwork.com/service/packages/chatwork/subpackages/api/apply_beta_business.php">here</a>.'
  string :room, :placeholder => 'Room ID',
         :label => 'Specify the Room ID where you want to send messages.<br />' \
                   'Room ID is the numeric id shown in the URL of each group chat.<br />' \
                   'For example: if the URL of the group chat where you want to send messages ' \
                   'is chatwork.com/#!rid00000, copy "00000", and paste it here.'

  page 'API Token', [:api_token]
  page 'Room ID', [:room]

  def receive_verification(config, _)
    send_message(config, receive_verification_message)
    [true, "Successfully sent a message to room #{config[:room]}"]
  rescue => e
    log "Rescued a verification error in ChatWork: #{e}"
    [false, "Could not send a message to room #{config[:room]}. #{e.message}"]
  end

  def receive_issue_impact_change(config, payload)
    send_message(config, format_issue_impact_change_message(payload))
  end

  private

  def receive_verification_message
    'Boom! Crashlytics issue change notifications have been added. For more info: ' \
    'http://support.crashlytics.com/knowledgebase/articles/349341-what-kind-of-third-party-integrations-does-crashly'
  end

  def format_issue_impact_change_message(payload)
    "[info][title]Notification from Crashlytics[/title];( " \
    "#{payload[:url]} " \
    "[#{payload[:app][:name]} - #{payload[:app][:bundle_identifier]}] Issue ##{payload[:display_id]}: " \
    "#{payload[:title]} #{payload[:method]}" \
    "[/info]"
  end

  def send_message(config, message)
    res = http_post "https://api.chatwork.com/v1/rooms/#{config[:room]}/messages" do |req|
      req.headers['X-ChatWorkToken'] = config[:api_token]
      req.params['body'] = message
    end
    if res.status < 200 || res.status > 299
      raise "Could not send a message to room. HTTP Error: #{res.status}. #{res.body}"
    end
    JSON.parse(res.body)
  end
end

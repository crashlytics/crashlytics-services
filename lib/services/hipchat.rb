require 'hipchat'

class Service::HipChat < Service::Base
  title 'HipChat'
  logo 'v1/settings/app_settings/hipchat.png'

  string :api_token, :placeholder => 'API Token',
         :label => 'Your HipChat API Token. <br />' \
                   'You can create a token' \
                   '<a href="https://www.hipchat.com/admin/api">here</a>.'
  string :room, :placeholder => 'Room ID or Name', :label => 'The ID or name of the room.'
  boolean :notify, :label => 'Should a notification be triggered for people in the room?'

  def receive_verification(config, _)
    send_message(config, receive_verification_message)
    [true, "Successfully sent a mesage to room #{ config[:room] }"]
  rescue
    [false, "Could not send a message to room #{ config[:room] }"]
  end

  def receive_issue_impact_change(config, payload)
    send_message(config, format_issue_impact_change_message(payload))
    :no_resource
  end

  private

  def receive_verification_message
    'Adding Crashlytics crash notifications in HipChat,' \
    '<a href="http://support.crashlytics.com/knowledgebase/articles/118543-what-kind-of-third-party-integrations-does-crashly">' \
    'see this for more info</a>.'
  end

  def format_issue_impact_change_message(payload)
    "<a href=#{ payload[:url].to_s }>" \
    "[#{ payload[:app][:name] }] #{ payload[:title] } in #{ payload[:method] }" \
    '</a>'
  end

  def send_message(config, message)
    token = config[:api_token]
    room = config[:room]
    client = HipChat::Client.new(token)    
    client[room].send('Crashlytics', message, config[:notify]) 
  end
end

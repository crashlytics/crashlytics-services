require 'tinder'

class Service::Campfire < Service::Base
  title 'Campfire'
  logo 'v1/settings/app_settings/campfire.png'
  string :subdomain, :label => 'Your Campfire subdomain:'
  string :room, :label => 'Your Campfire chatrooom:'
  string :api_token, :label => "Get it from Campfire's \"My Info\" screen."

  page 'Chatroom', [:subdomain, :room]
  page 'API Token', [:api_token]

  # Post an issue to Campfire room
  def receive_issue_impact_change(config, payload)
    room = find_campfire_room(config)
    users_text = ''
    crashes_text = ''
    if payload[:impacted_devices_count] == 1
      users_text = 'This issue is affecting at least 1 user who has crashed '
    else
      users_text = "This issue is affecting at least #{payload[:impacted_devices_count]} users who have crashed "
    end
    if payload[:crashes_count] == 1
      crashes_text = 'at least 1 time. '
    else
      "at least #{payload[:crashes_count]} times. "
    end

    message = "[#{payload[:app][:name]}] #{payload[:title]} in #{payload[:method]} "
    message << users_text
    message << crashes_text
    message << payload[:url].to_s

    resp = room.speak(message)
    unless resp.is_a?(Hash) && resp.message
      raise "Campfire Message Post Failed: #{(resp.map {|e| e.join(' ') }).join(', ')}"
    end
    { :campfire_message_id => resp.message.id }
  end

  def receive_verification(config, _)
    room = find_campfire_room(config)
    if room.nil?
      [false, "Oops! Can not find #{config[:room]} room. Please check your settings."]
    elsif room.name == config[:room]
      [true,  "Successfully verified Campfire settings"]
    end
    rescue ::Tinder::AuthenticationFailed => e
      [false, 'Oops! Is your API token correct?']
    rescue => e
      log "Rescued a verification error in campfire: #{e}"
      [false, "Oops! Encountered an unexpected error (#{e}). Please check your settings."]
  end

  private
  def find_campfire_room(config)
    campfire = ::Tinder::Campfire.new(config[:subdomain], :token => config[:api_token])
    campfire.find_room_by_name(config[:room])
  end
end

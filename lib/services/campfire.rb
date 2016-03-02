class Service::Campfire < Service::Base
  title 'Campfire'

  string :subdomain, :label => 'Your Campfire subdomain:'
  string :room, :label => 'Your Campfire chatroom:'
  password :api_token, :label => "Get it from Campfire's \"My Info\" screen."

  def initialize(config, logger = Proc.new)
    super
    configure_http
  end

  # Post an issue to Campfire room
  def receive_issue_impact_change(payload)
    room = find_campfire_room

    display_error("Could not find Campfire room: #{config[:room]}") unless room

    users_text = if payload[:impacted_devices_count] == 1
      'This issue is affecting at least 1 user who has crashed '
    else
      "This issue is affecting at least #{payload[:impacted_devices_count]} users who have crashed "
    end

    crashes_text = if payload[:crashes_count] == 1
      'at least 1 time. '
    else
      "at least #{payload[:crashes_count]} times. "
    end

    message = "[#{payload[:app][:name]}] #{payload[:title]} in #{payload[:method]} "
    message << users_text
    message << crashes_text
    message << payload[:url].to_s

    response = http_post("#{campfire_url}/room/#{room['id']}/speak") do |request|
      request.headers.merge!(request_headers)
      request.body = {
        :message => {
          :body => message
        }
      }.to_json
    end

    if response.success?
      log('issue_impact_change successful')
    else
      display_error("Could not send Campfire message: #{error_response_details(response)}")
    end
  end

  def receive_verification
    if find_campfire_room
      log('verification successful')
    else
      display_error("Oops! Can not find #{config[:room]} room. Please check your settings.")
    end
  end

  private

  def configure_http
    http.basic_auth(config[:api_token], nil)
  end

  def find_campfire_room
    response = http_get("#{campfire_url}/rooms") do |request|
      request.headers.merge!(request_headers)
    end

    if response.success?
      json = JSON.parse(response.body)
      room = json['rooms'].find { |room| room['name'] == config[:room] }
    end
  end

  def campfire_url
    "https://#{config[:subdomain]}.campfirenow.com"
  end

  def request_headers
    {
      'Accept' => 'application/json',
      'Content-type' => 'application/json'
    }
  end
end

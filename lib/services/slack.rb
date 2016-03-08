require 'json'

class Service::Slack < Service::Base
  title 'Slack'
  handles :issue_impact_change, :issue_velocity_alert

  string :url, :placeholder => 'Incoming Webhook URL',
                 :label => 'Your Slack Incoming Webhook. <br />' \
                   'You can find your Incoming webhook url under existing integrations in your slack account.'
  string :channel, :placeholder => '#general', :label => 'The name of the channel to post to.'
  string :username, :placeholder => 'crashlytics', :label => 'The name of the user to use when posting.'

  def receive_verification
    response = send_message(verification_message)

    if response.status == 200
      log('verification successful')
    else
      display_error(error_response_message(response))
    end
  end

  def receive_issue_impact_change(payload)
    message = "<#{payload[:url]}|#{payload[:app][:name]}> crashed #{payload[:crashes_count]} times in #{payload[:method]}!"
    attachment = build_attachment(
      "#{payload[:app][:name]} crashed #{payload[:crashes_count]} times in #{payload[:method]}!",
      :payload => payload,
      :color => 'warning'
    )
    response = send_message(message, { :attachments => [attachment] })
    if response.status == 200
      log('issue_impact_change successful')
    else
      display_error(error_response_message(response))
    end
  end

  def receive_issue_velocity_alert(payload)
    message = "Velocity Alert! <#{payload[:url]}|#{issue_title_string(payload)}> crashed #{payload[:crash_percentage]}% of all #{payload[:app][:name]} sessions in the past hour on version #{payload[:version]}"
    attachment = build_attachment(
      "Velocity Alert! #{issue_title_string(payload)} crashed #{payload[:crash_percentage]}% of all #{payload[:app][:name]} sessions in the past hour on version #{payload[:version]}",
      :payload => payload
    )
    response = send_message(message, { :attachments => [attachment] })
    if response.status == 200
      log('issue_velocity_alert successful')
    else
      display_error(error_response_message(response))
    end
  end


  private

  def error_response_message(response)
    "Unexpected response from Slack - #{error_response_details(response)}"
  end

  def verification_message
    'Boom! Crashlytics issue notifications have been added.  ' \
    '<http://support.crashlytics.com/knowledgebase/articles/349341-what-kind-of-third-party-integrations-does-crashly|' \
    'Click here for more info>.'
  end

  def issue_title_string(payload)
    "Issue ##{payload[:display_id]}: #{payload[:title]} #{payload[:method]}"
  end

  def build_attachment(fallback, options = {})
    options = options.dup # clone to prevent destruction of input
    payload = options.delete(:payload)

    attachment = {
      :fallback => fallback,
      :color => 'danger',
      :mrkdwn_in => ['text', 'fields']
    }.merge(options)

    if payload
      summary = issue_title_string(payload)
      attachment[:fields] = [
        { :title => 'Summary', :value => summary },
        { :title => 'Platform', :value => payload[:app][:platform], :short => true },
        { :title => 'Bundle identifier', :value => payload[:app][:bundle_identifier], :short => true }
      ]
    end

    attachment
  end

  def send_message(message, options = {})
    url = config[:url]
    channel = config[:channel]
    username = config[:username]

    http_post url do |req|
      req.headers['Content-Type'] = 'application/json'
      req.body = {
        :text => message,
        :channel => channel,
        :username => username
      }.merge(options).to_json
    end
  end
end

require 'slack-notifier'
require 'json'

class Service::Slack < Service::Base
  title 'Slack'

  string :url, :placeholder => 'Incoming Webhook URL',
                 :label => 'Your Slack Incoming Webhook. <br />' \
                   'You can find your Incoming webhook url under existing integrations in your slack account.'
  string :channel, :placeholder => '#general', :label => 'The name of the channel to post to.'
  string :username, :placeholder => 'crashlytics', :label => 'The name of the user to use when posting.'

  def receive_verification
    response = send_message(config, verification_message)

    if response.code == '200'
      log('verification successful')
    else
      display_error(error_response_message(response))
    end
  end

  def receive_issue_impact_change(payload)
    message, options = format_issue_impact_change_message(payload)
    response = send_message(config, message, options)
    if response.code == '200'
      log('issue_impact_change successful')
    else
      display_error(error_response_message(response))
    end
  end

  private

  def error_response_message(response)
    "Unexpected response from Slack - HTTP status code: #{response.code}"
  end

  def verification_message
    'Boom! Crashlytics issue change notifications have been added.  ' \
    '<http://support.crashlytics.com/knowledgebase/articles/349341-what-kind-of-third-party-integrations-does-crashly|' \
    'Click here for more info>.'
  end

  def format_issue_impact_change_message(payload)
    message = "<#{payload[:url].to_s}|#{payload[:app][:name]}> crashed #{payload[:crashes_count]} times in #{payload[:method]}!" 
    attachment = {
                fallback: "Issue ##{payload[:title]} was created. platform: #{payload[:app][:platform]}",
                color: 'danger',
                mrkdwn_in: ["text", "title", "fields", "fallback"],
                fields: [{title: 'Summary', value: "Issue ##{payload[:title]} was created for method #{payload[:method]}."},
                          {title: 'Platform', value: payload[:app][:platform], short: 'true'}, 
                          {title: 'Bundle identifier', value: payload[:app][:bundle_identifier], short: 'true'}]
              }

    options = { attachments: [attachment]}
    [message, options]
  end

  def send_message(config, message, options = {})
    url = config[:url]
    channel = config[:channel]
    username = config[:username]

    client = Slack::Notifier.new url, channel: channel, username: username

    client.ping(message, options)
  end
end

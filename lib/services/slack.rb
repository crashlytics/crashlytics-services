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
    send_message(config, verification_message)
    [true, "Successfully sent a message to channel #{ config[:channel] }"]
  rescue => e
    log "Rescued a verification error in Slack: #{ e.message }"
    [false, "Could not send a message to channel #{ config[:channel] }. #{e.message}"]
  end

  def receive_issue_impact_change(payload)
    message, options = format_issue_impact_change_message(payload)
    send_message(config, message, options)
    :no_resource
  end

  private

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

    response = client.ping(message, options)

    unless response.code == '200'
      raise "Unexpected response from Slack: #{response.code}"
    end
  end
end

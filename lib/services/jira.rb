require 'rubygems'
require 'pp'
require 'uri'
require 'json'

class Service::Jira < Service::Base
  title "Jira"
  handles :issue_impact_change, :issue_velocity_alert

  string :project_url, :placeholder => "https://yourdomain.atlassian.net/projects/XX",
         :label => 'Your Jira project URL:'
  string :username, :placeholder => 'username',
         :label => "These values are encrypted to ensure your security. <br /><br />" \
                   'Your Jira username:'
  password :password, :placeholder => 'password',
         :label => 'Your Jira password:'
  string :issue_type, :placeholder => 'Bug', :required => false,
         :label => '(Optional) Issue Type:'

  def initialize(config, logger = Proc.new {})
    super(config, logger)
    url_components = parse_url(config[:project_url])
    configure_http(url_components[:protocol])
    @base_api_url = [url_components[:protocol], url_components[:domain], url_components[:context_path]].join
    @project_key = url_components[:project_key]
  end

  def receive_verification
    lookup_jira_project
    log('verification successful')
  end

  def receive_issue_impact_change(payload)
    users_text = if payload[:impacted_devices_count] == 1
      'This issue is affecting at least 1 user who has crashed '
    else
      "This issue is affecting at least #{payload[:impacted_devices_count]} users who have crashed "
    end

    crashes_text = if payload[:crashes_count] == 1
      "at least 1 time.\n\n"
    else
      "at least #{payload[:crashes_count]} times.\n\n"
    end

    description = "Crashlytics detected a new issue.\n" + \
      "#{payload[:title]} in #{payload[:method]}\n\n" + \
      users_text + \
      crashes_text + \
      "More information: #{payload[:url]}"

    create_jira_issue("#{payload[:title]} [Crashlytics]", description)
    log('issue_impact_change successful')
  end

  def receive_issue_velocity_alert(payload)
    description = "Velocity alert!\n" + \
      "#{payload[:title]} in #{payload[:method]}\n\n" + \
      "This issue crashed #{payload[:crash_percentage]}% of all #{payload[:app][:name]} " + \
      "sessions in the past hour on version #{payload[:version]}" + \
      "More information: #{payload[:url]}"

    create_jira_issue("#{payload[:title]} [Crashlytics]", description)
    log('issue_velocity_alert successful')
  end

  def lookup_jira_project
    api_url = "#{@base_api_url}/rest/api/2/project/#{@project_key}"

    resp = http_get(api_url)

    if resp.success?
      JSON.parse(resp.body)
    else
      display_error "Jira Verification Failed - #{error_response_details(resp)}"
    end
  end

  def create_jira_issue(summary, description)
    project = lookup_jira_project

    post_body = {
      :fields => {
        :project => { :id => project['id'] },
        :summary => summary,
        :description => description,
        :issuetype => {
          :name => config[:issue_type] || 'Bug'
        }
      }
    }

    api_url = "#{@base_api_url}/rest/api/2/issue"

    resp = http_post(api_url, post_body.to_json) do |req|
      req.headers['Content-Type'] = 'application/json'
    end

    if resp.success?
      log('create_jira_issue successful')
    else
      log_error_details(resp)
      display_error "Jira Issue Create Failed - #{error_response_details(resp)}"
    end
  end

  def configure_http(protocol_str)
    http.basic_auth(config[:username], config[:password])
    if protocol_str =~ /https/
      http.ssl.verify = true
      http.ssl.verify_mode = OpenSSL::SSL::VERIFY_PEER
    else
      http.ssl.verify = false
      http.ssl.verify_mode = OpenSSL::SSL::VERIFY_NONE
    end
  end

  def parse_url(url)
    matches = url.match(/(https?:\/\/)(.+?)(\/.+)?\/(projects|browse)\/([\w\-]+)/)
    if matches.nil?
      raise "Unexpected URL format"
    end
    { :protocol => matches[1], :domain => matches[2], :context_path => matches[3] || '', :project_key => matches[5] }
  end

  def log_error_details(response)
    if response.body && response.body =~ /error/
      log("error details: #{response.body}")
    end
  end
end

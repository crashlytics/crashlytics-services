require 'rubygems'
require 'pp'
require 'jira'
require 'uri'

class Service::Jira < Service::Base
  title "Jira"

  string :project_url, :placeholder => "https://yourdomain.atlassian.net/projects/XX",
         :label => 'Your Jira project URL:'
  string :username, :placeholder => 'username',
         :label => "These values are encrypted to ensure your security. <br /><br />" \
                   'Your Jira username:'
  password :password, :placeholder => 'password',
         :label => 'Your Jira password:'
  string :issue_type, :placeholder => 'Bug', :required => false,
         :label => '(Optional) Issue Type:'

  page "Project", [ :project_url ]
  page "Login Information", [ :username, :password ]
  page "Customizations", [ :issue_type ]

  # Create an issue on Jira
  def receive_issue_impact_change(config, payload)
    url_components = parse_url(config[:project_url])
    client = jira_client(config, url_components[:context_path])

    project = client.Project.find(url_components[:project_key])

    users_text = if payload[:impacted_devices_count] == 1
      'This issue is affecting at least 1 user who has crashed '
    else
      "This issue is affecting at least #{ payload[:impacted_devices_count] } users who have crashed "
    end

    crashes_text = if payload[:crashes_count] == 1
      "at least 1 time.\n\n"
    else
      "at least #{ payload[:crashes_count] } times.\n\n"
    end

    issue_description = "Crashlytics detected a new issue.\n" + \
                 "#{ payload[:title] } in #{ payload[:method] }\n\n" + \
                 users_text + \
                 crashes_text + \
                 "More information: #{ payload[:url] }"

    post_body = { 'fields' => {
        'project' => { 'id' => project.id },
        'summary'     => payload[:title] + ' [Crashlytics]',
        'description' => issue_description,
        'issuetype' => { 'name' => config[:issue_type] || 'Bug' }
      }
    }

    # The Jira client raises an HTTPError if the response is not of the type Net::HTTPSuccess
    issue = client.Issue.build
    if issue.save(post_body)
      true
    else
      raise "Jira Issue Create Failed - Errors are: #{issue.respond_to?(:errors) ? issue.errors : {}}"
    end
  rescue JIRA::HTTPError => e
    raise "Jira Issue Create Failed - #{error_details(e)}"
  end

  def receive_verification(config, payload)
    url_components = parse_url(config[:project_url])
    client = jira_client(config, url_components[:context_path])

    resp = client.Project.find(url_components[:project_key])
    [true,  'Successfully verified Jira settings']
  rescue JIRA::HTTPError => e
    error_message = "Unexpected HTTP response from Jira - #{error_details(e)}"
    log error_message
    [false, error_message]
  end

  def error_details(error)
    "Message: #{error.message}, Status: #{error.code}"
  end

  def jira_client(config, context_path)
    url = config[:project_url]
    ssl_enabled = (URI(url).scheme == 'https')
    ssl_verify_mode = ssl_enabled ? OpenSSL::SSL::VERIFY_PEER : OpenSSL::SSL::VERIFY_NONE
    JIRA::Client.new(
      :username =>     config[:username],
      :password =>     config[:password],
      :site =>         config[:project_url],
      :context_path => context_path,
      :auth_type =>    :basic,
      :use_ssl =>      ssl_enabled,
      :ssl_verify_mode => ssl_verify_mode
    )
  end

  def parse_url(url)
    matches = url.match(/(https?:\/\/.+?)(\/.+)?\/(projects|browse)\/([\w\-]+)/)
    if matches.nil?
      raise "Unexpected URL format"
    end
    { :url_prefix => matches[1], :context_path => matches[2] || '', :project_key => matches[4] }
  end
end

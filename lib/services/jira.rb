require 'rubygems'
require 'pp'
require 'jira'
require 'uri'

class Service::Jira < Service::Base
  title "Jira"

  string :project_url, :placeholder => "https://domain.atlassian.net/browse/projectkey",
         :label => 'URL to your Jira project: <br />' \
                   'This should be your URL after you select your project ' \
                   'under the "Projects" tab.'
  string :username, :placeholder => 'username',
         :label => "These values are encrypted to ensure your security. <br /><br />" \
                   'Your Jira username:'
  password :password, :placeholder => 'password',
         :label => 'Your Jira password:'

  page "Project", [ :project_url ]
  page "Login Information", [ :username, :password ]

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
      'project' => {'id' => project.id},
      'summary'     => payload[:title] + ' [Crashlytics]',
      'description' => issue_description,
      'issuetype' => {'id' => '1'} } }

    # The Jira client raises an HTTPError if the response is not of the type Net::HTTPSuccess
    issue = client.Issue.build
    if issue.save(post_body)
      { :jira_story_id => issue.id, :jira_story_key => issue.key }
    else
      raise "Jira Issue Create Failed: #{issue.respond_to?(:errors) ? issue.errors : {}}"
    end

  rescue JIRA::HTTPError => e
    raise "Jira Issue Create Failed. Message: #{ e.message }, Status: #{ e.code }, Body: #{ e.response.body }"
  end

  def receive_verification(config, payload)
    url_components = parse_url(config[:project_url])
    client = jira_client(config, url_components[:context_path])

    resp = client.Project.find(url_components[:project_key])
    [true,  'Successfully verified Jira settings']
  rescue JIRA::HTTPError => e
    log "HTTP Error: status code: #{ e.code }, body: #{ e.response.body }"
    [false, 'Oops! Please check your settings again.']
  rescue => e
    log "Rescued a verification error in jira: (url=#{config[:project_url]}) #{e}"
    [false, 'Oops! Is your project url correct?']
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

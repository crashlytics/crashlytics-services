class Service::Jira < Service::Base
  title "Jira 5"

  string :project_url, :placeholder => "https://domain.atlassian.net/browse/projectkey",
         :label => 'URL to your Jira 5 project: <br />' \
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
    parsed = parse_url config[:project_url]
    project_key = parsed[:project_key]
    http.ssl[:verify] = true
    http.basic_auth config[:username], config[:password]

    resp = http_get "#{parsed[:url_prefix]}/rest/api/2/project/#{project_key}"
    # Get the numeric project id from the JIRA project key, so that we can post issues to this project.
    project_id = JSON.parse(resp.body).is_a?(Hash) ? JSON.parse(resp.body)['id'] : JSON.parse(resp.body)[0]['id']

    users_text = ""
    crashes_text = ""
    if payload[:impacted_devices_count] == 1
      users_text = "This issue is affecting at least 1 user who has crashed "
    else
      users_text = "This issue is affecting at least #{ payload[:impacted_devices_count] } users who have crashed "
    end
    if payload[:crashes_count] == 1
      crashes_text = "at least 1 time.\n\n"
    else
      "at least #{ payload[:crashes_count] } times.\n\n"
    end

    issue_description = "Crashlytics detected a new issue.\n" + \
                 "#{ payload[:title] } in #{ payload[:method] }\n\n" + \
                 users_text + \
                 crashes_text + \
                 "More information: #{ payload[:url] }"

    post_body = { 'fields' => {
      'project' => {'id' => project_id},
      'summary'     => payload[:title] + ' [Crashlytics]',
      'description' => issue_description,
      'issuetype' => {'id' => '1'} } }

    resp = http_post "#{parsed[:url_prefix]}/rest/api/2/issue" do |req|
      req.headers['Content-Type'] = 'application/json'
      req.body = post_body.to_json
    end
    if resp.status != 201
      raise "Jira Issue Create Failed: #{ resp[:status] }, body: #{ resp.body }"
    end
    { :jira_story_id => JSON.parse(resp.body)['id'] }
  end

  def receive_verification(config, _)
    parsed = parse_url config[:project_url]
    project_key      = parsed[:project_key]
    http.ssl[:verify] = true
    http.basic_auth config[:username], config[:password]

    resp = http_get "#{parsed[:url_prefix]}/rest/api/2/project/#{project_key}"
    if resp.status == 200
      [true,  "Successfully verified Jira settings"]
    else
      log "HTTP Error: status code: #{ resp.status }, body: #{ resp.body }"
      [false, "Oops! Please check your settings again."]
    end
  rescue => e
    log "Rescued a verification error in jira: (url=#{config[:project_url]}) #{e}"
    [false, "Oops! Is your project url correct?"]
  end

  private
  require 'uri'
  def parse_url(url)
    uri = URI(url)
    result = { :url_prefix => url.match(/(https?:\/\/.*?)\/browse\//)[1],
      :project_key => uri.path.match(/\/browse\/(.+?)(\/|$)/)[1]}
    result
  end
end

require 'rubygems'
require 'pp'
require 'jira'

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

  # TODO - This should not be on the master branch. This enables syncing
  #        of issue status between Jira and Crashlytics. This feature is a WIP.
  # checkbox :sync_issues, :label => 'Would you like to sync issue status with Jira?'

  page "Project", [ :project_url ]
  page "Login Information", [ :username, :password ] # TODO - See comment above, :sync_issues ]

  # Create an issue on Jira
  def receive_issue_impact_change(config, payload)
    client = jira_client(config)

    parsed = parse_url config[:project_url]
    project = client.Project.find(parsed[:project_key])

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

    issue_description = 'Crashlytics detected a new issue.\n' + \
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
    resp = client.post("#{parsed[:url_prefix]}/rest/api/2/issue", post_body.to_json)

    body = JSON.parse(resp.body)
    { :jira_story_id => body['id'], :jira_story_key => body['key'] }

  rescue JIRA::HTTPError => e
    raise "Jira Issue Create Failed. Message: #{ e.message }, Status: #{ e.code }, Body: #{ e.response.body }"
  rescue => e
    raise "Jira Issue Create Failed: #{ e.message }"
  end

  def receive_verification(config, payload)
    client = jira_client(config)

    parsed = parse_url config[:project_url]

    resp = client.Project.find(parsed[:project_key])
    verification_response = [true,  'Successfully verified Jira settings']

    if config[:sync_issues]
      begin
        register_webhook(client, payload)
      rescue JIRA::HTTPError => e
        log "HTTP Error: webhook request(status: #{ e.code }, message: #{ e.message })"
        verification_response = [true, 'Successfully verified Jira settings but Jira\'s webhook could not be registered. You need to use an Admin account to set it up.']
      end
    end
    verification_response
  rescue JIRA::HTTPError => e
    log "HTTP Error: status code: #{ e.code }, body: #{ e.response.body }"
    [false, 'Oops! Please check your settings again.']
  rescue => e
    log "Rescued a verification error in jira: (url=#{config[:project_url]}) #{e}"
    [false, 'Oops! Is your project url correct?']
  end

  # TODO - This should not be on master. The commented out methods
  #        support the incomplete issue syncing feature. 
  # def receive_issue_integration_request(config, payload)
  #   client = jira_client(config)

  #   jira_id = payload[:service_hook][:issue_impact_change][:jira_story_id]
  #   jira_issue = client.Issue.find(jira_id)

  #   format_jira_issue jira_issue
  # rescue => e
  #   log "Rescued a service hook request error in jira: (url=#{config[:project_url]}) #{e}"
  #   false
  # end

  # def receive_issue_resolution_change(config, payload)
  #   client = jira_client(config)

  #   jira_id = payload[:service_hook][:issue_impact_change][:jira_story_id]
  #   jira_issue = client.Issue.find(jira_id)

  #   if jira_issue.resolution.nil? && !payload[:resolved_at]
  #     log "Jira ticket #{jira_id} is open, no need to call API."
  #     return true
  #   elsif jira_issue.resolution.present? && payload[:resolved_at]
  #     log "Jira ticket #{jira_id} is resolved already."
  #     return true
  #   end

  #   transition_request = {
  #     :update => {
  #       :comment => [{
  #         :add => {
  #           :body => nil
  #         }
  #       }]
  #     },
  #     :transition => {
  #       :id => nil
  #     }
  #   }

  #   if payload[:resolved_at]
  #     transition_request[:update][:comment][0][:add][:body] = 'This CR has been marked as resolved in Crashlytics'
  #     transition_request[:transition][:id] = '2'
  #   else
  #     transition_request[:update][:comment][0][:add][:body] = 'This CR has been reopened in Crashlytics'
  #     transition_request[:transition][:id] = '3'
  #   end

  #   client.post("#{ jira_issue.self }/transitions?expand=transitions.fields", transition_request.to_json)

  #   format_jira_issue client.Issue.find(jira_id) # fetch updated issue and return it
  # rescue => e
  #  log "Rescued a service hook request error in jira: (url=#{config[:project_url]}) #{e.message}"
  #  false
  # end

  def jira_client(config)
    url = config[:project_url]
    ssl_enabled = (URI(url).scheme == 'https')
    ssl_verify_mode = ssl_enabled ? OpenSSL::SSL::VERIFY_PEER : OpenSSL::SSL::VERIFY_NONE
    JIRA::Client.new(
      :username =>     config[:username],
      :password =>     config[:password],
      :site =>         config[:project_url],
      :context_path => get_context_path(url),
      :auth_type =>    :basic,
      :use_ssl =>      ssl_enabled,
      :ssl_verify_mode => ssl_verify_mode
    )
  end

  private
  require 'uri'
  def parse_url(url)
    uri = URI(url)
    result = { :url_prefix => url.match(/(https?:\/\/.*?)\/browse\//)[1],
      :project_key => uri.path.match(/\/browse\/(.+?)(\/|$)/)[1]}
    result
  end

  def get_context_path(url)
    m = url.match(/https?:\/\/.*?..+?((?:\/.+)+)\/browse\//)
    m ? m[1] : ''
  end

  def callback_webhook_url(payload)
    "https://www.crashlytics.com/api/v3/projects/#{ payload[:app][:id] }/service_hooks/jira/responses"
  end

  def register_webhook(client, payload)
    new_webhook = callback_webhook_url(payload)

    # Unregister webhooks that look identical to avoid duplicates
    response = client.get('/rest/webhooks/1.0/webhook')
    current_hooks = JSON.parse(response.body)
    current_hooks.each do |hook|
      if hook['url'] == new_webhook
        client.delete(hook['self'])
      end
    end

    webhook_params = {
      'name' => 'Crashlytics Issue sync',
      'url' => new_webhook,
      'events' => ['jira:issue_updated'],
      'excludeIssueDetails' => false }

    client.post('/rest/webhooks/1.0/webhook', webhook_params.to_json)
  end

    JIRA_FIELDS = [
    'assignee',
    'created',
    'creator',
    'description',
    'issuetype',
    'priority',
    'project',
    'reporter',
    'resolution',
    'resolutiondate',
    'status',
    'summary',
    'updated'
  ]

  def format_jira_issue(jira_issue)
    response = {
      'id' => jira_issue.id,
      'key' => jira_issue.key
    }

    JIRA_FIELDS.each do |field|
      response[field] = jira_issue.fields[field]
      if response[field].respond_to? :delete
        response[field].delete 'self'
      end
    end

    if jira_issue.comments.present? && jira_issue.comments.size
      response['comments'] = []
      jira_issue.comments.each do |comment|
        comment.attrs.delete 'self'
        response['comments'] << comment.attrs
      end
    end

    response
  end
end

class Service::GitHub < Service::Base
  title 'GitHub'

  string :repo, :placeholder => 'org/repository', :label => 'Your GitHub repository:'
  password :access_token, :placeholder => 'GitHub access token', :label =>
    'You can create an access token ' \
    '<a target="_blank" href="https://help.github.com/articles/creating-an-access-token-for-command-line-use">here</a>, which can be revoked through GitHub at any time.<br /><br />' \
    'However, we strongly recommend that you create a new GitHub user for this, one that only has access to the repo with which you wish to integrate.<br /><br />' \
    'GitHub access token:'
  string :api_endpoint, :required => false,
    :label => '(GitHub Enterprise only) API endpoint:',
    :placeholder => 'https://github.yourcompany.com/api/v3/'

  STATUS_CODE_CREATED = 201

  def initialize(config, logger = Proc.new {})
    super
    configure_http
  end

  def receive_verification
    response = verify_repo_exists

    if response.success?
      log('verification successful')
    else
      display_error("Could not access repository for #{config[:repo]}.")
    end
  end

  def receive_issue_impact_change(issue)
    response = create_github_issue(issue)

    if response.status == STATUS_CODE_CREATED
      log 'issue_impact_change successful'
    else
      display_error("GitHub issue creation failed - #{error_response_details(response)}")
    end
  end

  private

  def configure_http
    http.authorization :token, config[:access_token]
  end

  def create_github_issue(issue)
    repo = config[:repo]
    issue_title = issue[:title]
    issue_body = format_issue_impact_change_payload(issue)

    http_post("#{repository_url}/issues") do |request|
      request.headers.merge!(request_headers)
      request.body = {
        :labels => [],
        :title => issue_title,
        :body => issue_body
      }.to_json
    end
  end

  def verify_repo_exists
    http_get(repository_url) do |request|
      request.headers.merge!(request_headers)
    end
  end

  def format_issue_impact_change_payload(issue)
    "#### in #{issue[:method]}\n" \
    "\n" \
    "* Number of crashes: #{issue[:crashes_count]}\n" \
    "* Impacted devices: #{issue[:impacted_devices_count]}\n" \
    "\n" \
    "There's a lot more information about this crash on crashlytics.com:\n" \
    "[#{issue[:url]}](#{issue[:url]})"
  end

  private

  def request_headers
    {
      'Content-type' => 'application/json',
      'Accept' => 'application/vnd.github.v3+json'
    }
  end

  def repository_url
    "#{github_url}/repos/#{config[:repo]}"
  end

  def github_url
    config[:api_endpoint] || 'https://api.github.com'
  end

end

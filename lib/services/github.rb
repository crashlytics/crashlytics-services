require 'octokit'

class Service::GitHub < Service::Base
  title 'GitHub'

  string :repo, :placeholder => 'org/repository', :label => 'Your GitHub repository:'
  string :access_token, :placeholder => 'GitHub access token', :label =>
    'You can create an access token ' \
    '<a target="_blank" href="https://help.github.com/articles/creating-an-access-token-for-command-line-use">here</a>, which can be revoked through GitHub at any time.<br /><br />' \
    'However, we strongly recommend that you create a new GitHub user for this, one that only has access to the repo with which you wish to integrate.<br /><br />' \
    'GitHub access token:'
  string :api_endpoint, :required => false,
    :label => '(GitHub Enterprise only) API endpoint:',
    :placeholder => 'https://github.yourcompany.com/api/v3/'

  STATUS_CODE_CREATED = 201

  def receive_verification
    verify_repo_exists(config)
    [true, "Successfully accessed repo #{config[:repo]}."]
  rescue => e
    log "Rescued a verification error in GitHub for repo #{config[:repo]}: #{e}"
    [false, "Could not access repository for #{config[:repo]}."]
  end

  def receive_issue_impact_change(issue)
    github_issue, status_code = create_github_issue(config, issue)

    if status_code == STATUS_CODE_CREATED
      { :github_issue_number => github_issue.number }
    else
      raise "GitHub issue creation failed: #{status_code} - #{github_issue.message}"
    end
  end

  private

  # Returns a [Sawyer::Resource, status code] tuple.
  # The resource will have different attrs depending on success or failure.
  def create_github_issue(config, issue)
    client = build_client(config)

    repo = config[:repo]
    issue_title = issue[:title]
    issue_body = format_issue_impact_change_payload(issue)

    github_issue = client.create_issue(repo, issue_title, issue_body)
    [github_issue, client.last_response.status]
  end

  # Returns GitHub repo, raising an exception if the access_token doesn't work.
  def verify_repo_exists(config)
    build_client(config).repo config[:repo]
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

  def build_client(config)
    Octokit::Client.new(
      :api_endpoint => config[:api_endpoint],
      :access_token => config[:access_token]
    )
  end
end

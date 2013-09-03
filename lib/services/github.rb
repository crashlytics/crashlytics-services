require 'octokit'

class Service::GitHub < Service::Base
  title 'GitHub'

  string :repo, :placeholder => 'org/repository', :label => 'Your GitHub repository.'
  string :access_token, :placeholder => 'GitHub access token', :label =>
    'We strongly recommend that you create a new GitHub user for this, one that only has access to the repo you wish to integrate with.' \
    '<br /><br />' \
    'You can create an access token ' \
    '<a target="_blank" href="https://help.github.com/articles/creating-an-access-token-for-command-line-use">here</a>, which can be revoked through GitHub at any time.'

  page 'Repository', [:repo]
  page 'Access token', [:access_token]

  def receive_verification(config, _)
    repo = github_repo(config[:access_token], config[:repo])
    [true, "Successsfully accessed repo #{config[:repo]}."]
  rescue => e
    log "Rescued a verification error in GitHub for repo #{config[:repo]}: #{e}"
    [false, "Could not access repository for #{config[:repo]}."]
  end

  def receive_issue_impact_change(config, issue)
    github_issue, status_code = create_github_issue(
      config[:access_token],
      config[:repo],
      issue[:title],
      format_issue_impact_change_payload(issue)
    )
    raise "GitHub issue creation failed: #{status_code} - #{github_issue.message}" unless status_code == 201
    { :github_issue_number => github_issue.number }
  end

  private

  # Returns a [Sawyer::Resource, status code] tuple.
  # The resource will have different attrs depending on success or failure.
  def create_github_issue(access_token, repo, title, body)
    client = Octokit::Client.new :access_token => access_token
    github_issue = client.create_issue(repo, title, body)
    [github_issue, client.last_response.status]
  end

  # Returns GitHub repo, raising an exception if the access_token doesn't work.
  def github_repo(access_token, repo)
    client = Octokit::Client.new :access_token => access_token
    client.repo repo
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
end

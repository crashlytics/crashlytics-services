=begin

Create bitbucket issues for new crashes.

User inputs are password and project url.
User name and project name will be parsed from project url.

Project url is in format https://bitbucket.org/user_name/project_name

Ref API : https://confluence.atlassian.com/display/BITBUCKET/issues+Resource#issuesResource-POSTanewissue
API Test : http://restbrowser.bitbucket.org/

=end

class Service::Bitbucket < Service::Base

  title "Bitbucket"

  string :username, :placeholder => 'username',
    :label =>
      'Your credentials will be encrypted. ' \
      'However, we strongly recommend that you create a separate ' \
      'Bitbucket account for integration with Crashlytics. ' \
      'Limit the account\'s write access to the repo you want ' \
      'to post issues to.' \
      '<br /><br />' \
      'Please make sure you have issues enabled for your Bitbucket ' \
      'repository. Instructions for Bitbucket can be found here: ' \
      'https://confluence.atlassian.com/display/BITBUCKET' \
      '<br /><br />' \
      'Example url: ' \
      'https://bitbucket.org/example-owner/example-repo' \
      '<br /><br />' \
      'Your Bitbucket username:'
  password :password, :placeholder => 'password',
     :label => 'Your Bitbucket password:'
  string :repo_owner, :placeholder => 'example-owner',
    :label =>
      'The owner of your repo (enter your username again if you are the repo owner):'

  string :repo, :placeholder => "example-repo",
    :label =>
      'The name of your repo:'

  def receive_verification
    username = config[:username]
    repo = config[:repo]
    http.ssl[:verify] = true
    http.basic_auth username, config[:password]

    resp = http_get build_url(repo_owner(config), repo)

    if resp.status == 200
      log('verification successful')
    else
      log "Verification error - #{error_response_details(resp)}"
      display_error('Oops! Please check your settings again.')
    end
  rescue => e
    log "Rescued a verification error in bitbucket: (repo=#{config[:repo]}) #{e}"
    display_error("Oops! Is your repository url correct?")
  end

  def receive_issue_impact_change(payload)
    username = config[:username]
    repo = config[:repo]
    http.ssl[:verify] = true
    http.basic_auth username, config[:password]

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

    post_body = {
      :kind => 'bug',
      :title => payload[:title] + ' [Crashlytics]',
      :content => issue_description
    }

    resp = http_post build_url(repo_owner(config), repo) do |req|
      req.body = post_body
    end

    if resp.status != 200
      display_error("Bitbucket issue creation failed - #{error_response_details(resp)}")
    end

    log('issue_impact_change successful')
  end

  def build_url(repo_owner, repo)
    url_prefix = 'https://bitbucket.org/api/1.0/repositories'
    "#{url_prefix}/#{repo_owner}/#{repo}/issues"
  end

  private

  def nil_or_empty?(str)
    str.to_s.strip.empty?
  end

  def repo_owner(config)
    repo_owner = config[:repo_owner]
    if nil_or_empty?(repo_owner)
      config[:username]
    else
      repo_owner
    end
  end
end

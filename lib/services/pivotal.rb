class Service::Pivotal < Service::Base
  string :project_url, :placeholder => "https://www.pivotaltracker.com/projects/yourproject/",
         :label => "URL to your Pivotal project:"
  string :api_key, :label => 'Paste your API Token (located under "Profile"). ' \
                             'Make sure API Access is on for your project in Project Settings!<br />' \
                             'Tip: Create a Crashlytics user for easier sorting.'

  page "Project", [ :project_url ]
  page "API Token", [ :api_key ]

  # Create an issue on Pivotal
  def receive_issue_impact_change(config, payload)
    parsed = parse_url config[:project_url]
    project_id = parsed[:project_id]
    http.ssl[:verify] = true

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

    issue_body = "Crashlytics detected a new issue.\n" + \
                 "*#{ payload[:title] }* in _#{ payload[:method] }_\n\n" + \
                 users_text + \
                 crashes_text + \
                 "More information: #{ payload[:url] }"
    post_body = {
      'name'     => payload[:title] + ' [Crashlytics]',
      'requested_by'  => 'Crashlytics',
      'story_type'    => 'bug',
      'description' => issue_body }

    resp = http_post "https://#{parsed[:url_prefix]}/services/v3/projects/#{project_id}/stories" do |req|
      req.headers['Content-Type'] = 'application/xml'
      req.headers['X-TrackerToken'] = config[:api_key]
      req.params[:token] = config[:api_key]
      req.body = post_to_xml(post_body)
    end
    if resp.status < 200 || resp.status > 299
      raise "Pivotal Issue Create Failed: #{ resp[:status] }, #{ resp.body }"
    end
    { :pivotal_story_id => ::Nokogiri::XML::Document.parse(resp.body).xpath('/story/id').children().first().content() }
  end

  def receive_verification(config, _)
    parsed = parse_url config[:project_url]
    project_id      = parsed[:project_id]
    http.ssl[:verify] = true

    resp = http_get "https://#{parsed[:url_prefix]}/services/v3/projects/#{project_id}" do |req|
      req.headers['X-TrackerToken'] = config[:api_key]
    end
    if resp.status == 200
      [true,  "Successfully verified Pivotal settings"]
    else
      log "HTTP Error: status code: #{ resp.status }, body: #{ resp.body }"
      [false, "Oops! Please check your settings again."]
    end
  rescue => e
    log "Rescued a verification error in pivotal: (url=#{config[:project_url]}) #{e}"
    [false, "Oops! Is your project url correct?"]
  end

  private
  require 'uri'
  def parse_url(url)
    uri = URI(url)
    { :url_prefix => url.match(/https?:\/\/(.*?)\/projects\//)[1],
      :project_id => uri.path.match(/\/projects\/(.+?)(\/|$)/)[1]}
  end

  private
  def post_to_xml(contents)
    builder = ::Nokogiri::XML::Builder.new do |xml|
      xml.story {
        xml.name "#{contents['name']}"
        xml.description "#{contents['description']}"
        xml.story_type "#{contents['story_type']}"
        # xml.estimate "#{contents['estimate']}"
        # xml.current_state "#{contents['current_state']}"
        # xml.requested_by "#{contents['requested_by']}"
        # xml.owned_by "#{contents['owned_by']}"
        # xml.labels "#{contents['labels']}"
        # xml.project_id "#{contents['project_id']}"
        # xml.other_id "#{contents['other_id']}"
        # xml.integration_id "#{contents['integration_id']}"
      }
    end
    builder.to_xml
  end
end

class Service::Trello < Service::Base
  title 'Trello'

  string :board, placeholder: 'Board ID',
    label:
      'Your Trello board id:' \
      '<br />' \
      'Example: 4d5ea62fd76aa1136000000c (Trello Development board)'
  string :list,  placeholder: 'List name',
    label: 'The list to post issues to:'
  string :key,   placeholder: 'Developer public key',
    label:
      'Your Trello API key:' \
      '<br />' \
      'Can be obtained <a href="https://trello.com/1/appKey/generate">here</a> (Key field)'
  password :token, placeholder: 'Member token',
                 label: <<-EOT
You should generate a token by opening the following URL. Replace DEVELOPER_PUBLIC_KEY with your key.
<textarea readonly="true">
https://trello.com/1/authorize?key=DEVELOPER_PUBLIC_KEY&name=Crashlytics&response_type=token&scope=read,write&expiration=never
</textarea>
Grant access to your account by pressing the Allow button. Paste the returned token into this field.
EOT

  def receive_verification
    find_list
    log('verification successful')
  end

  def receive_issue_impact_change(issue)
    create_card(issue)
    log('issue_impact_change successful')
  end

  private

  def card_params(issue)
    { 'name' => issue[:title],
      'desc' => card_description(issue) }
  end

  def card_description(issue)
    <<-EOT
#### in #{issue[:method]}

* Number of crashes: #{issue[:crashes_count]}
* Impacted devices: #{issue[:impacted_devices_count]}

There's a lot more information about this crash on crashlytics.com:
#{issue[:url]}
EOT
  end

  def failure_message(response_body)
    if response_body =~ /invalid token/
      "Token #{config[:token]} is invalid"
    elsif response_body =~ /invalid key/
      "Key #{config[:key]} is invalid"
    else
      "Board #{config[:board]} was not found"
    end
  end

  def find_board
    response = http_get "https://api.trello.com/1/boards/#{config[:board]}", auth_params

    if response.success?
      JSON.parse(response.body)
    else
      display_error(failure_message(response.body))
    end
  end

  def find_list
    board_id = find_board['id']
    response = http_get "https://api.trello.com/1/boards/#{board_id}/lists", auth_params.merge(:filter => 'open')

    if response.success?
      lists = JSON.parse(response.body)
      list = lists.find { |list| list['name'] == config[:list] } || display_missing_list_error
    else
      display_error(failure_message(response.body))
    end
  end

  def display_missing_list_error
    display_error("List #{config[:list]} not found in board #{config[:board]}")
  end

  def create_card(issue)
    list = find_list

    response = http_post "https://api.trello.com/1/cards?key=#{config[:key]}&token=#{config[:token]}", auth_params do |req|
      req.params.merge(auth_params)
      req.body = {
        :desc => card_description(issue),
        :idList => list['id'],
        :name => issue[:title]
      }
    end

    if response.success?
      # no-op
    else
      display_error("Unexpected error while creating a card - #{error_response_details(response)}")
    end
  end

  def auth_params
    { :key => config[:key], :token => config[:token] }
  end
end

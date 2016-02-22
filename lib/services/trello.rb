require 'trello'

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
  string :token, placeholder: 'Member token',
                 label: <<-EOT
You should generate a token by opening the following URL. Replace DEVELOPER_PUBLIC_KEY with your key.
<textarea readonly="true">
https://trello.com/1/authorize?key=DEVELOPER_PUBLIC_KEY&name=Crashlytics&response_type=token&scope=read,write&expiration=never
</textarea>
Grant access to your account by pressing the Allow button. Paste the returned token into this field.
EOT

  def receive_verification
    find_list config
    [true, "Successfully found board #{config[:board]} with list #{config[:list]}"]
  rescue Trello::Error => e
    [false, failure_message(config, e)]
  end

  def receive_issue_impact_change(issue)
    list = find_list config
    client = trello_client(config[:key], config[:token])
    card = client.create :card, card_params(issue).merge('idList' => list.id)
    { trello_card_id: card.id }
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

  def trello_client(key, token)
    Trello::Client.new developer_public_key: key, member_token: token
  end

  def failure_message(config, e)
    if e.message =~ /invalid token/
      "Token #{config[:token]} is invalid"
    elsif e.message =~ /invalid key/
      "Key #{config[:key]} is invalid"
    elsif e.message =~ /invalid list/
      "Unable to find list #{config[:list]} in board #{config[:board]}"
    else
      "Board #{config[:board]} was not found"
    end
  end

  def find_list(config)
    board = trello_client(config[:key], config[:token]).find :boards, config[:board]
    board.lists.find { |list| list.name == config[:list] } || fail(Trello::Error, 'invalid list')
  end
end

require 'services/web_hook'

class Service::Moxtra < Service::WebHook
  title "Moxtra"
  string :url, :placeholder => 'Incoming Webhook URL',
         :label => 'Your Moxtra Incoming Webhook URL. <br />' \
                   'You can find your incoming webhook url under integrations in your Moxtra account.'
end

require 'services/web_hook'

class Service::Appaloosa < Service::WebHook
  title "Appaloosa"
  string :url, :placeholder => 'Incoming Webhook URL',
         :label => 'Your Appaloosa Incoming Webhook URL. <br />' \
                   'You can find your incoming webhook url under the issues section in application details.'
end

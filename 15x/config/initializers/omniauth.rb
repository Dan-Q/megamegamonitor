# Set up omniauth-reddit middleware

# Based upon https://github.com/jackdempsey/omniauth-reddit/blob/master/lib/omniauth/strategies/reddit.rb
# but removes mobile detection (MegaMegaMonitor always uses the same authorize url)

require 'omniauth/strategies/oauth2'
require 'base64'
require 'rack/utils'

module OmniAuth
  module Strategies
    class Reddit < OmniAuth::Strategies::OAuth2
      option :name, "reddit"
      option :authorize_options, [:scope, :duration]

      option :client_options, {
               site: 'https://oauth.reddit.com',
               token_url: 'https://www.reddit.com/api/v1/access_token',
               authorize_url: 'https://www.reddit.com/api/v1/authorize'
             }

      uid { raw_info['id'] }

      info do
        {
          name: raw_info['name']
        }
      end

      extra do
        {'raw_info' => raw_info}
      end
      def raw_info
        @raw_info ||= access_token.get('/api/v1/me').parsed || {}
      end

      def build_access_token
        options.token_params.merge!(:headers => {'Authorization' => basic_auth_header })
        super
      end

      def basic_auth_header
        "Basic " + Base64.strict_encode64("#{options[:client_id]}:#{options[:client_secret]}")
      end
    end
  end
end

Rails.application.config.middleware.use OmniAuth::Builder do
  provider :reddit, ENV['REDDIT_KEY'], ENV['REDDIT_SECRET'],
           duration: 'temporary',
           scope: 'identity',
           provider_ignores_state: true
end

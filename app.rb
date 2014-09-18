require 'guillotine'
require 'redis'

module Katana
  class App < Guillotine::App

    uri   = URI.parse ENV["REDISTOGO_URL"]

    redis = Redis.new host: uri.host,
                      port: uri.port,
                      password: uri.password

    adapter = Guillotine::Adapters::RedisAdapter.new redis

    set service: Guillotine::Service.new(adapter)

    # authenticate everything except GETs
    before { protected! if request.request_method != "GET" }

    get "/" do
      redirect "http://voxxit.com"
    end

    helpers do

      # Private: helper method to protect URLs with Rack Basic Auth
      #
      # Throws 401 if authorization fails
      def protected!
        return unless ENV["HTTP_USER"]

        unless authorized?
          response['WWW-Authenticate'] = %(Basic realm="Restricted Area")
          throw(:halt, [401, "Not authorized\n"])
        end
      end

      # Private: helper method to check if authorization parameters match the set environment variables
      #
      # Returns true or false
      def authorized?
        @auth ||= Rack::Auth::Basic::Request.new(request.env)

        @auth.provided? && @auth.basic? && @auth.credentials && @auth.credentials == [
          ENV["HTTP_USER"],
          ENV["HTTP_PASS"]
        ]
      end

    end

  end
end

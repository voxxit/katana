$secret = ENV["SECRET"]
$db_url = ENV["REDISTOGO_URL"]
$alpha  = ENV["ALPHABET"]

raise "SECRET & REDISTOGO_URL required. Check `heroku config`" if [$secret, $db_url].any? { |v| !v or v.empty? }

if $alpha.nil? or $alpha.empty?
  raise "ALPHABET required. Update `heroku config` with: (('a'..'z').to_a + ('A'..'Z').to_a + (0..9).to_a).shuffle.join"
end

# dependencies
require "guillotine"
require "redis"
require "minuteman"

require_relative "lib/bijective"

# connect to redis
uri = URI.parse($db_url)
redis = Redis.new(host: uri.host, port: uri.port, password: uri.password)

# for click tracking
analytics = Minuteman.new(redis: redis)

module Katana
  class App < Guillotine::App

    use Rack::Session::Cookie, expire_after: 2592000, secret: secret

    adapter = Guillotine::Adapters::RedisAdapter.new(redis)

    set service: Guillotine::Service.new(adapter,
      default_url: ENV["DEFAULT_URL"],
      strip_anchor: false,
      strip_query: false
    )

    # authenticate everything except GETs
    before { protected! if request.request_method != "GET" }

    get "/:code" do
      # track the code hit
      analytics.track("url:hit", session["uid"] ||= SecureRandom.uuid)

      escaped = Addressable::URI.escape(params[:code])
      status, head, body = settings.service.get(escaped)
      [status, head, simple_escape(body)]
    end

    helpers do

      # Private: helper method to protect URLs with Rack Basic Auth
      #
      # Throws 401 if authorization fails
      def protected!
        return if ENV["HTTP_USER"].nil?
        return if authorized?

        response['WWW-Authenticate'] = %(Basic realm="Restricted Area")

        throw :halt, [401, "Not authorized\n"]
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

module ActiveResource
  module Railties
    class Subscriber < Rails::Subscriber
      def request(event)
        result, site = event.payload[:result], event.payload[:site]
        info "#{event.payload[:method].to_s.upcase} #{site.scheme}://#{site.host}:#{site.port}#{event.payload[:path]}"
        info "--> %d %s %d (%.1fms)" % [result.code, result.message, result.body.to_s.length, event.duration]
      end

      def logger
        ActiveResource::Base.logger
      end
    end
  end
end
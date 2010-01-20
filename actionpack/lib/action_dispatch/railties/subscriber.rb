module ActionDispatch
  module Railties
    class Subscriber < Rails::Subscriber
      def before_dispatch(event)
        request = Request.new(event.payload[:env])
        path    = request.request_uri.inspect rescue "unknown"

        info "\n\nStarted #{request.method.to_s.upcase} #{path} " <<
             "for #{request.remote_ip} at #{event.time.to_s(:db)}"
      end

      def logger
        ActionController::Base.logger
      end
    end
  end
end
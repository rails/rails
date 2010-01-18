module ActionDispatch
  module Railties
    class Subscriber < Rails::Subscriber
      def before_dispatch(event)
        request = Request.new(event.payload[:env])
        path    = request.request_uri.inspect rescue "unknown"

        info "\n\nProcessing #{path} to #{request.formats.join(', ')} " <<
             "(for #{request.remote_ip} at #{event.time.to_s(:db)}) [#{request.method.to_s.upcase}]"
      end

      def logger
        ActionController::Base.logger
      end
    end
  end
end
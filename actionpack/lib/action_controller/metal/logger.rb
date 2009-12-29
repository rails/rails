require 'abstract_controller/logger'

module ActionController
  module Logger
    # Override process_action in the AbstractController::Base
    # to log details about the method.
    def process_action(action)
      result = ActiveSupport::Notifications.instrument(:process_action,
                :controller => self, :action => action) do
        super
      end

      if logger
        log = AbstractController::Logger::DelayedLog.new do
          "\n\nProcessing #{self.class.name}\##{action_name} " \
          "to #{request.formats} (for #{request_origin}) " \
          "[#{request.method.to_s.upcase}]"
        end

        logger.info(log)
      end

      result
    end

  private

    # Returns the request origin with the IP and time. This needs to be cached,
    # otherwise we would get different results for each time it calls.
    def request_origin
      @request_origin ||= "#{request.remote_ip} at #{Time.now.to_s(:db)}"
    end
  end
end

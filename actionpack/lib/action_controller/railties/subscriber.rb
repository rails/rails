module ActionController
  module Railties
    class Subscriber < Rails::Subscriber
      def process_action(event)
        payload = event.payload
        info "  Parameters: #{payload[:params].inspect}" unless payload[:params].blank?

        additions = ActionController::Base.log_process_action(payload)

        message = "Completed in %.0fms" % event.duration
        message << " (#{additions.join(" | ")})" unless additions.blank?
        message << " by #{payload[:controller]}##{payload[:action]} [#{payload[:status]}]"

        info(message)
      end

      def send_file(event)
        message = if event.payload[:x_sendfile]
          header = ActionController::Streaming::X_SENDFILE_HEADER
          "Sent #{header} header %s"
        elsif event.payload[:stream]
          "Streamed file %s"
        else
          "Sent file %s"
        end

        message << " (%.1fms)"
        info(message % [event.payload[:path], event.duration])
      end

      def redirect_to(event)
        info "Redirected to #{event.payload[:location]}"
      end

      def send_data(event)
        info("Sent data %s (%.1fms)" % [event.payload[:filename], event.duration])
      end

      %w(write_fragment read_fragment exist_fragment?
         expire_fragment expire_page write_page).each do |method|
        class_eval <<-METHOD, __FILE__, __LINE__ + 1
          def #{method}(event)
            key_or_path = event.payload[:key] || event.payload[:path]
            human_name  = #{method.to_s.humanize.inspect}
            info("\#{human_name} \#{key_or_path} (%.1fms)" % event.duration)
          end
        METHOD
      end

      def logger
        ActionController::Base.logger
      end
    end
  end
end
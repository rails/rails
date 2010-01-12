module ActionController
  module Railties
    class Subscriber < Rails::Subscriber
      def process_action(event)
        controller = event.payload[:controller]
        request    = controller.request

        info "\nProcessed #{controller.class.name}##{event.payload[:action]} " \
          "to #{request.formats} (for #{request.remote_ip} at #{event.time.to_s(:db)}) " \
          "[#{request.method.to_s.upcase}]"

        params = controller.send(:filter_parameters, request.params)
        info "  Parameters: #{params.inspect}" unless params.empty?

        ActionController::Base.log_process_action(controller)

        message = "Completed in %.0fms" % event.duration
        message << " | #{controller.response.status}"
        message << " [#{request.request_uri rescue "unknown"}]\n\n"

        info(message)
      end

      def send_file(event)
        message = if event.payload[:x_sendfile]
          header = ActionController::Streaming::X_SENDFILE_HEADER
          "Sending #{header} header %s"
        elsif event.payload[:stream]
          "Streaming file %s"
        else
          "Sending file %s"
        end

        message << " (%.1fms)"
        info(message % [event.payload[:path], event.duration])
      end

      def redirect_to(event)
        info "Redirected to #{event.payload[:location]} with status #{event.payload[:status]}"
      end

      def send_data(event)
        info("Sending data %s (%.1fms)" % [event.payload[:filename], event.duration])
      end

      %w(write_fragment read_fragment exist_fragment?
         expire_fragment expire_page write_page).each do |method|
        class_eval <<-METHOD, __FILE__, __LINE__ + 1
          def #{method}(event)
            key_or_path = event.payload[:key] || event.payload[:path]
            human_name  = #{method.to_s.humanize.inspect}
            info("\#{human_name} \#{key_or_path.inspect} (%.1fms)" % event.duration)
          end
        METHOD
      end

      def logger
        ActionController::Base.logger
      end
    end
  end
end
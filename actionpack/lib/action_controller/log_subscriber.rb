require 'active_support/core_ext/object/blank'

module ActionController
  class LogSubscriber < ActiveSupport::LogSubscriber
    INTERNAL_PARAMS = %w(controller action format _method only_path)

    def start_processing(event)
      payload = event.payload
      params  = payload[:params].except(*INTERNAL_PARAMS)

      info "  Processing by #{payload[:controller]}##{payload[:action]} as #{payload[:formats].first.to_s.upcase}"
      info "  Parameters: #{params.inspect}" unless params.empty?
    end

    def process_action(event)
      payload   = event.payload
      additions = ActionController::Base.log_process_action(payload)

      message = "Completed #{payload[:status]} #{Rack::Utils::HTTP_STATUS_CODES[payload[:status]]} in %.0fms" % event.duration
      message << " (#{additions.join(" | ")})" unless additions.blank?

      info(message)
    end

    def send_file(event)
      message = "Sent file %s"
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

ActionController::LogSubscriber.attach_to :action_controller
module ActionController
  class LogSubscriber < ActiveSupport::LogSubscriber
    INTERNAL_PARAMS = %w(controller action format _method only_path)

    def start_processing(event)
      return unless logger.info?

      payload = event.payload
      params  = payload[:params].except(*INTERNAL_PARAMS)
      format  = payload[:format]
      format  = format.to_s.upcase if format.is_a?(Symbol)

      info "Processing by #{payload[:controller]}##{payload[:action]} as #{format}"
      info "  Parameters: #{params.inspect}" unless params.empty?
    end

    def process_action(event)
      info do
        payload   = event.payload
        additions = ActionController::Base.log_process_action(payload)

        status = payload[:status]
        if status.nil? && payload[:exception].present?
          exception_class_name = payload[:exception].first
          status = ActionDispatch::ExceptionWrapper.status_code_for_exception(exception_class_name)
        end
        message = "Completed #{status} #{Rack::Utils::HTTP_STATUS_CODES[status]} in #{event.duration.round}ms"
        message << " (#{additions.join(" | ")})" unless additions.blank?
        message
      end
    end

    def halted_callback(event)
      info { "Filter chain halted as #{event.payload[:filter].inspect} rendered or redirected" }
    end

    def send_file(event)
      info { "Sent file #{event.payload[:path]} (#{event.duration.round(1)}ms)" }
    end

    def redirect_to(event)
      info { "Redirected to #{event.payload[:location]}" }
    end

    def send_data(event)
      info { "Sent data #{event.payload[:filename]} (#{event.duration.round(1)}ms)" }
    end

    def unpermitted_parameters(event)
      debug do
        unpermitted_keys = event.payload[:keys]
        "Unpermitted parameter#{'s' if unpermitted_keys.size > 1}: #{unpermitted_keys.join(", ")}"
      end
    end

    def deep_munge(event)
      debug do
        "Value for params[:#{event.payload[:keys].join('][:')}] was set "\
        "to nil, because it was one of [], [null] or [null, null, ...]. "\
        "Go to http://guides.rubyonrails.org/security.html#unsafe-query-generation "\
        "for more information."\
      end
    end

    %w(write_fragment read_fragment exist_fragment?
       expire_fragment expire_page write_page).each do |method|
      class_eval <<-METHOD, __FILE__, __LINE__ + 1
        def #{method}(event)
          return unless logger.info?
          key_or_path = event.payload[:key] || event.payload[:path]
          human_name  = #{method.to_s.humanize.inspect}
          info("\#{human_name} \#{key_or_path} (\#{event.duration.round(1)}ms)")
        end
      METHOD
    end

    def logger
      ActionController::Base.logger
    end
  end
end

ActionController::LogSubscriber.attach_to :action_controller

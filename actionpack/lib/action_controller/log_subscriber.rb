# frozen_string_literal: true

module ActionController
  class LogSubscriber < ActiveSupport::LogSubscriber
    INTERNAL_PARAMS = %w(controller action format _method only_path)

    def start_processing(event)
      return unless logger.info?

      payload = event.payload
      params = {}
      payload[:params].each_pair do |k, v|
        params[k] = v unless INTERNAL_PARAMS.include?(k)
      end
      format  = payload[:format]
      format  = format.to_s.upcase if format.is_a?(Symbol)
      format  = "*/*" if format.nil?

      info "Processing by #{payload[:controller]}##{payload[:action]} as #{format}"
      info "  Parameters: #{params.inspect}" unless params.empty?
    end
    subscribe_log_level :start_processing, :info

    def process_action(event)
      info do
        payload = event.payload
        additions = ActionController::Base.log_process_action(payload)
        status = payload[:status]

        if status.nil? && (exception_class_name = payload[:exception]&.first)
          status = ActionDispatch::ExceptionWrapper.status_code_for_exception(exception_class_name)
        end

        additions << "Allocations: #{event.allocations}"

        message = +"Completed #{status} #{Rack::Utils::HTTP_STATUS_CODES[status]} in #{event.duration.round}ms" \
                   " (#{additions.join(" | ")})"
        message << "\n\n" if defined?(Rails.env) && Rails.env.development?

        message
      end
    end
    subscribe_log_level :process_action, :info

    def halted_callback(event)
      info { "Filter chain halted as #{event.payload[:filter].inspect} rendered or redirected" }
    end
    subscribe_log_level :halted_callback, :info

    def send_file(event)
      info { "Sent file #{event.payload[:path]} (#{event.duration.round(1)}ms)" }
    end
    subscribe_log_level :send_file, :info

    def redirect_to(event)
      info { "Redirected to #{event.payload[:location]}" }
    end
    subscribe_log_level :redirect_to, :info

    def send_data(event)
      info { "Sent data #{event.payload[:filename]} (#{event.duration.round(1)}ms)" }
    end
    subscribe_log_level :send_data, :info

    def unpermitted_parameters(event)
      debug do
        unpermitted_keys = event.payload[:keys]
        display_unpermitted_keys = unpermitted_keys.map { |e| ":#{e}" }.join(", ")
        context = event.payload[:context].map { |k, v| "#{k}: #{v}" }.join(", ")
        color("Unpermitted parameter#{'s' if unpermitted_keys.size > 1}: #{display_unpermitted_keys}. Context: { #{context} }", RED)
      end
    end
    subscribe_log_level :unpermitted_parameters, :debug

    %w(write_fragment read_fragment exist_fragment? expire_fragment).each do |method|
      class_eval <<-METHOD, __FILE__, __LINE__ + 1
        # frozen_string_literal: true
        def #{method}(event)
          return unless ActionController::Base.enable_fragment_cache_logging
          key         = ActiveSupport::Cache.expand_cache_key(event.payload[:key] || event.payload[:path])
          human_name  = #{method.to_s.humanize.inspect}
          info("\#{human_name} \#{key} (\#{event.duration.round(1)}ms)")
        end
        subscribe_log_level :#{method}, :info
      METHOD
    end

    def logger
      ActionController::Base.logger
    end
  end
end

ActionController::LogSubscriber.attach_to :action_controller

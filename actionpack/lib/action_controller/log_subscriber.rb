# frozen_string_literal: true

module ActionController
  class LogSubscriber < ActiveSupport::EventReporter::LogSubscriber # :nodoc:
    INTERNAL_PARAMS = %w(controller action format _method only_path)

    class_attribute :backtrace_cleaner, default: ActiveSupport::BacktraceCleaner.new

    self.namespace = "action_controller"

    def request_started(event)
      payload = event[:payload]
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
    event_log_level :request_started, :info

    def request_completed(event)
      info do
        payload = event[:payload]
        additions = ActionController::Base.log_process_action(payload)
        status = payload[:status]

        if status.nil? && (exception_class_name = payload[:exception]&.first)
          status = ActionDispatch::ExceptionWrapper.status_code_for_exception(exception_class_name)
        end

        additions << "GC: #{payload[:gc_time_ms].round(1)}ms"

        message = +"Completed #{status} #{Rack::Utils::HTTP_STATUS_CODES[status]} in #{payload[:duration_ms].round(0)}ms" \
                   " (#{additions.join(" | ")})"
        message << "\n\n" if defined?(Rails.env) && Rails.env.development?

        message
      end
    end
    event_log_level :request_completed, :info

    def callback_halted(event)
      info { "Filter chain halted as #{event[:payload][:filter].inspect} rendered or redirected" }
    end
    event_log_level :callback_halted, :info

    # Manually subscribed below
    def rescue_from_handled(event)
      exception_class = event[:payload][:exception_class]
      exception_message = event[:payload][:exception_message]
      exception_backtrace = event[:payload][:exception_backtrace]
      info { "rescue_from handled #{exception_class} (#{exception_message}) - #{exception_backtrace}" }
    end
    event_log_level :rescue_from_handled, :info

    def file_sent(event)
      info { "Sent file #{event[:payload][:path]} (#{event[:payload][:duration_ms].round(1)}ms)" }
    end
    event_log_level :file_sent, :info

    def redirected(event)
      info { "Redirected to #{event[:payload][:location]}" }

      if ActionDispatch.verbose_redirect_logs && (source = redirect_source_location)
        info { "↳ #{source}" }
      end
    end
    event_log_level :redirected, :info

    def data_sent(event)
      info { "Sent data #{event[:payload][:filename]} (#{event[:payload][:duration_ms].round(1)}ms)" }
    end
    event_log_level :data_sent, :info

    def unpermitted_parameters(event)
      debug do
        unpermitted_keys = event[:payload][:unpermitted_keys]
        display_unpermitted_keys = unpermitted_keys.map { |e| ":#{e}" }.join(", ")
        context = event[:payload][:context].map { |k, v| "#{k}: #{v}" }.join(", ")
        color("Unpermitted parameter#{'s' if unpermitted_keys.size > 1}: #{display_unpermitted_keys}. Context: { #{context} }", RED)
      end
    end
    event_log_level :unpermitted_parameters, :debug

    def csrf_token_fallback(event)
      return unless ActionController::Base.log_warning_on_csrf_failure

      warn do
        payload = event[:payload]
        "Falling back to CSRF token verification for #{payload[:controller]}##{payload[:action]}"
      end
    end
    event_log_level :csrf_token_fallback, :info

    def csrf_request_blocked(event)
      return unless ActionController::Base.log_warning_on_csrf_failure

      warn { event[:payload][:message] }
    end
    event_log_level :csrf_request_blocked, :info

    def csrf_javascript_blocked(event)
      return unless ActionController::Base.log_warning_on_csrf_failure

      warn { event[:payload][:message] }
    end
    event_log_level :csrf_javascript_blocked, :info

    def fragment_cache(event)
      return unless ActionController::Base.enable_fragment_cache_logging

      key        = event[:payload][:key]
      human_name = event[:payload][:method].to_s.humanize

      info("#{human_name} #{key} (#{event[:payload][:duration_ms]}ms)")
    end
    event_log_level :fragment_cache, :info

    def self.default_logger
      ActionController::Base.logger
    end

    private
      def redirect_source_location
        backtrace_cleaner.first_clean_frame
      end
  end
end

ActiveSupport.event_reporter.subscribe(
  ActionController::LogSubscriber.new, &ActionController::LogSubscriber.subscription_filter
)

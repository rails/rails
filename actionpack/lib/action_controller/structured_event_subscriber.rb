# frozen_string_literal: true

module ActionController
  class StructuredEventSubscriber < ActiveSupport::StructuredEventSubscriber # :nodoc:
    INTERNAL_PARAMS = %w(controller action format _method only_path)

    def start_processing(event)
      payload = event.payload
      params = {}
      payload[:params].each_pair do |k, v|
        params[k] = v unless INTERNAL_PARAMS.include?(k)
      end
      format = payload[:format]
      format = format.to_s.upcase if format.is_a?(Symbol)
      format = "*/*" if format.nil?

      emit_event("action_controller.request_started",
        controller: payload[:controller],
        action: payload[:action],
        format:,
        params:,
      )
    end

    def process_action(event)
      payload = event.payload
      status = payload[:status]

      if status.nil? && (exception_class_name = payload[:exception]&.first)
        status = ActionDispatch::ExceptionWrapper.status_code_for_exception(exception_class_name)
      end

      emit_event("action_controller.request_completed", {
        controller: payload[:controller],
        action: payload[:action],
        status: status,
        **additions_for(payload),
        duration_ms: event.duration.round(2),
        gc_time_ms: event.gc_time.round(1),
      }.compact)
    end

    def halted_callback(event)
      emit_event("action_controller.callback_halted", filter: event.payload[:filter])
    end

    def rescue_from_callback(event)
      exception = event.payload[:exception]

      exception_backtrace = exception.backtrace&.first
      exception_backtrace = exception_backtrace&.delete_prefix("#{Rails.root}/") if defined?(Rails.root) && Rails.root

      emit_event("action_controller.rescue_from_handled",
        exception_class: exception.class.name,
        exception_message: exception.message,
        exception_backtrace:
      )
    end

    def send_file(event)
      emit_event("action_controller.file_sent", path: event.payload[:path], duration_ms: event.duration.round(1))
    end

    def redirect_to(event)
      emit_event("action_controller.redirected", location: event.payload[:location])
    end

    def send_data(event)
      emit_event("action_controller.data_sent", filename: event.payload[:filename], duration_ms: event.duration.round(1))
    end

    def unpermitted_parameters(event)
      unpermitted_keys = event.payload[:keys]
      context = event.payload[:context]

      emit_debug_event("action_controller.unpermitted_parameters",
        unpermitted_keys:,
        context: context.except(:request)
      )
    end
    debug_only :unpermitted_parameters

    def write_fragment(event)
      fragment_cache(__method__, event)
    end

    def read_fragment(event)
      fragment_cache(__method__, event)
    end

    def exist_fragment?(event)
      fragment_cache(__method__, event)
    end

    def expire_fragment(event)
      fragment_cache(__method__, event)
    end

    private
      def fragment_cache(method_name, event)
        key = ActiveSupport::Cache.expand_cache_key(event.payload[:key] || event.payload[:path])

        emit_event("action_controller.fragment_cache",
          method: "#{method_name}",
          key: key,
          duration_ms: event.duration.round(1)
        )
      end

      def additions_for(payload)
        payload.slice(:view_runtime, :db_runtime, :queries_count, :cached_queries_count)
      end
  end
end

ActionController::StructuredEventSubscriber.attach_to :action_controller

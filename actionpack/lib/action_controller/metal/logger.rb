require 'abstract_controller/logger'

module ActionController
  # Adds instrumentation to <tt>process_action</tt> and a <tt>log_event</tt> method
  # responsible to log events from ActiveSupport::Notifications. This module handles
  # :process_action and :render_template events but allows any other module to hook
  # into log_event and provide its own logging facilities (as in ActionController::Caching).
  module Logger
    extend ActiveSupport::Concern

    included do
      include AbstractController::Logger
    end

    attr_internal :view_runtime

    def process_action(action)
      ActiveSupport::Notifications.instrument(:process_action, :controller => self, :action => action) do
        super
      end
    end

    def render(*args, &block)
      if logger
        render_output = nil

        self.view_runtime = cleanup_view_runtime do
          Benchmark.ms { render_output = super }
        end

        render_output
      else
        super
      end
    end

    # If you want to remove any time taken into account in :view_runtime
    # wrongly, you can do it here:
    #
    #   def cleanup_view_runtime
    #     super - time_taken_in_something_expensive
    #   end
    #
    # :api: plugin
    def cleanup_view_runtime #:nodoc:
      yield
    end

    module ClassMethods
      # This is the hook invoked by ActiveSupport::Notifications.subscribe.
      # If you need to log any event, overwrite the method and do it here.
      def log_event(name, before, after, instrumenter_id, payload) #:nodoc:
        if name == :process_action
          duration     = [(after - before) * 1000, 0.01].max
          controller   = payload[:controller]
          request      = controller.request

          logger.info "\n\nProcessed #{controller.class.name}##{payload[:action]} " \
            "to #{request.formats} (for #{request.remote_ip} at #{before.to_s(:db)}) " \
            "[#{request.method.to_s.upcase}]"

          log_process_action(controller)

          message = "Completed in %.0fms" % duration
          message << " | #{controller.response.status}"
          message << " [#{request.request_uri rescue "unknown"}]"

          logger.info(message)
        elsif name == :render_template
          # TODO Make render_template logging work if you are using just ActionView
          duration = (after - before) * 1000
          message = "Rendered #{payload[:identifier]}"
          message << " within #{payload[:layout]}" if payload[:layout]
          message << (" (%.1fms)" % duration)
          logger.info(message)
        end
      end

    protected

      # A hook which allows logging what happened during controller process action.
      # :api: plugin
      def log_process_action(controller) #:nodoc:
        view_runtime = controller.send :view_runtime
        logger.info("  View runtime: %.1fms" % view_runtime.to_f) if view_runtime
      end
    end
  end
end
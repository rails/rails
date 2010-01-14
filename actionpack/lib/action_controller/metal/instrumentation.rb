require 'abstract_controller/logger'

module ActionController
  # Adds instrumentation to several ends in ActionController::Base. It also provides
  # some hooks related with process_action logging and view runtime.
  module Instrumentation
    extend ActiveSupport::Concern

    included do
      include AbstractController::Logger
    end

    attr_internal :view_runtime

    def process_action(action, *args)
      ActiveSupport::Notifications.instrument("action_controller.process_action",
        :controller => self, :action => action) do
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

    def send_file(path, options={})
      ActiveSupport::Notifications.instrument("action_controller.send_file",
        options.merge(:path => path)) do
        super
      end
    end

    def send_data(data, options = {})
      ActiveSupport::Notifications.instrument("action_controller.send_data", options) do
        super
      end
    end

    def redirect_to(*args)
      super
      ActiveSupport::Notifications.instrument("action_controller.redirect_to",
        :status => self.status, :location => self.location)
    end

    # A hook which allows you to clean up any time taken into account in
    # views wrongly, like database querying time.
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
      # A hook which allows other frameworks to log what happened during
      # controller process action. This method should return an array
      # with the messages to be added.
      # :api: plugin
      def log_process_action(controller) #:nodoc:
        messages, view_runtime = [], controller.send(:view_runtime)
        messages << ("Views: %.1fms" % view_runtime.to_f) if view_runtime
        messages
      end
    end
  end
end
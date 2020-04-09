# frozen_string_literal: true

require "benchmark"
require "abstract_controller/logger"

module ActionController
  # Adds instrumentation to several ends in ActionController::Base. It also provides
  # some hooks related with process_action. This allows an ORM like Active Record
  # and/or DataMapper to plug in ActionController and show related information.
  #
  # Check ActiveRecord::Railties::ControllerRuntime for an example.
  module Instrumentation
    extend ActiveSupport::Concern

    include AbstractController::Logger

    attr_internal :view_runtime

    def process_action(*)
      raw_payload = {
        controller: self.class.name,
        action: action_name,
        request: request,
        params: request.filtered_parameters,
        headers: request.headers,
        format: request.format.ref,
        method: request.request_method,
        path: request.fullpath
      }

      ActiveSupport::Notifications.instrument("start_processing.action_controller", raw_payload)

      ActiveSupport::Notifications.instrument("process_action.action_controller", raw_payload) do |payload|
        result = super
        payload[:response] = response
        payload[:status]   = response.status
        result
      ensure
        append_info_to_payload(payload)
      end
    end

    def render(*)
      render_output = nil
      self.view_runtime = cleanup_view_runtime do
        Benchmark.ms { render_output = super }
      end
      render_output
    end

    def send_file(path, options = {})
      ActiveSupport::Notifications.instrument("send_file.action_controller",
        options.merge(path: path)) do
        super
      end
    end

    def send_data(data, options = {})
      ActiveSupport::Notifications.instrument("send_data.action_controller", options) do
        super
      end
    end

    def redirect_to(*)
      ActiveSupport::Notifications.instrument("redirect_to.action_controller", request: request) do |payload|
        result = super
        payload[:status]   = response.status
        payload[:location] = response.filtered_location
        result
      end
    end

  private
    # A hook invoked every time a before callback is halted.
    def halted_callback_hook(filter, _)
      ActiveSupport::Notifications.instrument("halted_callback.action_controller", filter: filter)
    end

    # A hook which allows you to clean up any time, wrongly taken into account in
    # views, like database querying time.
    #
    #   def cleanup_view_runtime
    #     super - time_taken_in_something_expensive
    #   end
    def cleanup_view_runtime # :doc:
      yield
    end

    # Every time after an action is processed, this method is invoked
    # with the payload, so you can add more information.
    def append_info_to_payload(payload) # :doc:
      payload[:view_runtime] = view_runtime
    end

    module ClassMethods
      # A hook which allows other frameworks to log what happened during
      # controller process action. This method should return an array
      # with the messages to be added.
      def log_process_action(payload) #:nodoc:
        messages, view_runtime = [], payload[:view_runtime]
        messages << ("Views: %.1fms" % view_runtime.to_f) if view_runtime
        messages
      end
    end
  end
end

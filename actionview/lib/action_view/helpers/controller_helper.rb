require 'active_support/core_ext/module/attr_internal'

module ActionView
  module Helpers
    # This module keeps all methods and behavior in ActionView
    # that simply delegates to the controller.
    module ControllerHelper #:nodoc:
      attr_internal :controller, :request

      CONTROLLER_DELEGATES = [:request_forgery_protection_token, :params,
        :session, :cookies, :response, :headers, :flash, :action_name,
        :controller_name, :controller_path]

      delegate *CONTROLLER_DELEGATES, to: :controller

      def assign_controller(controller)
        if @_controller = controller
          @_request = controller.request if controller.respond_to?(:request)
          @_config  = controller.config.inheritable_copy if controller.respond_to?(:config)
          @_default_form_builder = controller.default_form_builder if controller.respond_to?(:default_form_builder)
        end
      end

      def logger
        controller.logger if controller.respond_to?(:logger)
      end

      def respond_to?(method_name, include_private = false)
        return controller.respond_to?(method_name) if CONTROLLER_DELEGATES.include?(method_name.to_sym)
        super
      end
    end
  end
end

require 'active_support/core_ext/module/attr_internal'

module ActionView
  module Helpers
    # This module keeps all methods and behavior in ActionView
    # that simply delegates to the controller.
    module ControllerHelper #:nodoc:
      attr_internal :controller, :request

      delegate :request_forgery_protection_token, :params, :session, :cookies, :response, :headers,
               :flash, :action_name, :controller_name, :controller_path, :to => :controller

      delegate :logger, :to => :controller, :allow_nil => true

      def assign_controller(controller)
        if @_controller = controller
          @_request = controller.request if controller.respond_to?(:request)
          @_config  = controller.config.inheritable_copy if controller.respond_to?(:config)
        end
      end
    end
  end
end
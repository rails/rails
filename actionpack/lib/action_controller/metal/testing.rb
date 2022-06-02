# frozen_string_literal: true

module ActionController
  module Testing
    # Behavior specific to functional tests
    module Functional # :nodoc:
      def clear_instance_variables_between_requests
        if defined?(@_ivars)
          new_ivars = instance_variables - @_ivars
          new_ivars.each { |ivar| remove_instance_variable(ivar) }
        end

        @_ivars = instance_variables
      end

      def recycle!
        @_url_options = nil
        self.formats = nil
        self.params = nil
      end
    end
  end
end

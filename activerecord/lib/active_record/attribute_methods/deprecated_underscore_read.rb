require 'active_support/concern'
require 'active_support/deprecation'

module ActiveRecord
  module AttributeMethods
    module DeprecatedUnderscoreRead
      extend ActiveSupport::Concern

      included do
        attribute_method_prefix "_"
      end

      module ClassMethods
        protected

        def define_method__attribute(attr_name)
          # Do nothing, let it hit method missing instead.
        end
      end

      protected

      def _attribute(attr_name)
        ActiveSupport::Deprecation.warn(
          "You have called '_#{attr_name}'. This is deprecated. Please use " \
          "either '#{attr_name}' or read_attribute('#{attr_name}')."
        )
        read_attribute(attr_name)
      end
    end
  end
end

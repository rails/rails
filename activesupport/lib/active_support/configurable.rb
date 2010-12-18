require 'active_support/concern'
require 'active_support/ordered_options'
require 'active_support/core_ext/kernel/singleton_class'
require 'active_support/core_ext/module/delegation'

module ActiveSupport
  module Configurable
    extend ActiveSupport::Concern

    module ClassMethods
      def config
        @_config ||= ActiveSupport::InheritableOptions.new(superclass.respond_to?(:config) ? superclass.config : {})
      end

      def configure
        yield config
      end

      # Allows you to add shortcut so that you don't have to refer to attribute through config.
      # Also look at the example for config to contrast.
      #
      #   class User
      #     include ActiveSupport::Configurable
      #     config_accessor :allowed_access
      #   end
      #
      #   user = User.new
      #   user.allowed_access = true
      #   user.allowed_access # => true
      #
      def config_accessor(*names)
        names.each do |name|
          code, line = <<-RUBY, __LINE__ + 1
            def #{name}; config.#{name}; end
            def #{name}=(value); config.#{name} = value; end
          RUBY

          singleton_class.class_eval code, __FILE__, line
          class_eval code, __FILE__, line
        end
      end
    end

    def config
      @_config ||= ActiveSupport::InheritableOptions.new(self.class.config)
    end
  end
end

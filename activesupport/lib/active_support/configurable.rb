require 'active_support/concern'
require 'active_support/ordered_options'
require 'active_support/core_ext/kernel/singleton_class'
require 'active_support/core_ext/module/delegation'

module ActiveSupport
  # Configurable provides a <tt>config</tt> method to store and retrieve
  # configuration options as an <tt>OrderedHash</tt>.
  module Configurable
    extend ActiveSupport::Concern

    module ClassMethods
      def config
        @_config ||= ActiveSupport::InheritableOptions.new(superclass.respond_to?(:config) ? superclass.config : {})
      end

      def configure
        yield config
      end

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

    # Reads and writes attributes from a configuration <tt>OrderedHash</tt>.
    # 
    #   require 'active_support/configurable'      
    #  
    #   class User
    #     include ActiveSupport::Configurable
    #   end 
    #
    #   user = User.new
    # 
    #   user.config.allowed_access = true
    #   user.config.level = 1
    #
    #   user.config.allowed_access # => true
    #   user.config.level          # => 1
    # 
    def config
      @_config ||= ActiveSupport::InheritableOptions.new(self.class.config)
    end
  end
end


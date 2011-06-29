require 'active_support/concern'
require 'active_support/ordered_options'
require 'active_support/core_ext/kernel/singleton_class'
require 'active_support/core_ext/module/delegation'
require 'active_support/core_ext/array/extract_options'

module ActiveSupport
  # Configurable provides a <tt>config</tt> method to store and retrieve
  # configuration options as an <tt>OrderedHash</tt>.
  module Configurable
    extend ActiveSupport::Concern

    class Configuration < ActiveSupport::InheritableOptions
      def compile_methods!
        self.class.compile_methods!(keys)
      end

      # compiles reader methods so we don't have to go through method_missing
      def self.compile_methods!(keys)
        keys.reject { |m| method_defined?(m) }.each do |key|
          class_eval <<-RUBY, __FILE__, __LINE__ + 1
            def #{key}; _get(#{key.inspect}); end
          RUBY
        end
      end
    end

    module ClassMethods
      def config
        @_config ||= if respond_to?(:superclass) && superclass.respond_to?(:config)
          superclass.config.inheritable_copy
        else
          # create a new "anonymous" class that will host the compiled reader methods
          Class.new(Configuration).new
        end
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
        options = names.extract_options!

        names.each do |name|
          reader, line = "def #{name}; config.#{name}; end", __LINE__
          writer, line = "def #{name}=(value); config.#{name} = value; end", __LINE__

          singleton_class.class_eval reader, __FILE__, line
          singleton_class.class_eval writer, __FILE__, line
          class_eval reader, __FILE__, line unless options[:instance_reader] == false
          class_eval writer, __FILE__, line unless options[:instance_writer] == false
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
      @_config ||= self.class.config.inheritable_copy
    end
  end
end


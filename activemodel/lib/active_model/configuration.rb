require 'active_support/concern'
require 'active_support/core_ext/class/attribute'
require 'active_support/core_ext/class/attribute_accessors'

module ActiveModel
  # This API is for Rails' internal use and is not currently considered 'public', so
  # it may change in the future without warning.
  #
  # It creates configuration attributes that can be inherited from a module down
  # to a class that includes the module. E.g.
  #
  #   module MyModel
  #     extend ActiveModel::Configuration
  #     config_attribute :awesome
  #     self.awesome = true
  #   end
  #
  #   class Post
  #     include MyModel
  #   end
  #
  #   Post.awesome # => true
  #
  #   Post.awesome = false
  #   Post.awesome    # => false
  #   MyModel.awesome # => true
  #
  # We assume that the module will have a ClassMethods submodule containing methods
  # to be transferred to the including class' singleton class.
  #
  # Config options can also be defined directly on a class:
  #
  #   class Post
  #     extend ActiveModel::Configuration
  #     config_attribute :awesome
  #   end
  #
  # So this allows us to define a module that doesn't care about whether it is being
  # included in a class or a module:
  #
  #   module Awesomeness
  #     extend ActiveSupport::Concern
  #
  #     included do
  #       extend ActiveModel::Configuration
  #       config_attribute :awesome
  #       self.awesome = true
  #     end
  #   end
  #
  #   class Post
  #     include Awesomeness
  #   end
  #
  #   module AwesomeModel
  #     include Awesomeness
  #   end
  module Configuration #:nodoc:
    def config_attribute(name, options = {})
      klass = self.is_a?(Class) ? ClassAttribute : ModuleAttribute
      klass.new(self, name, options).define
    end

    class Attribute
      attr_reader :host, :name, :options

      def initialize(host, name, options)
        @host, @name, @options = host, name, options
      end

      def instance_writer?
        options.fetch(:instance_writer, false)
      end
    end

    class ClassAttribute < Attribute
      def define
        if options[:global]
          host.cattr_accessor name, :instance_writer => instance_writer?
        else
          host.class_attribute name, :instance_writer => instance_writer?
        end
      end
    end

    class ModuleAttribute < Attribute
      def class_methods
        @class_methods ||= begin
          if host.const_defined?(:ClassMethods, false)
            host.const_get(:ClassMethods)
          else
            host.const_set(:ClassMethods, Module.new)
          end
        end
      end

      def define
        host.singleton_class.class_eval <<-CODE, __FILE__, __LINE__
          attr_accessor :#{name}
          def #{name}?; !!#{name}; end
        CODE

        name, host = self.name, self.host

        class_methods.class_eval do
          define_method(name) { host.send(name) }
          define_method("#{name}?") { !!send(name) }
        end

        host.class_eval <<-CODE
          def #{name};  defined?(@#{name}) ? @#{name} : self.class.#{name}; end
          def #{name}?; !!#{name}; end
        CODE

        if options[:global]
          class_methods.class_eval do
            define_method("#{name}=") { |val| host.send("#{name}=", val) }
          end
        else
          class_methods.class_eval <<-CODE, __FILE__, __LINE__
            def #{name}=(val)
              singleton_class.class_eval do
                remove_possible_method(:#{name})
                define_method(:#{name}) { val }
              end
            end
          CODE
        end

        host.send(:attr_writer, name) if instance_writer?
      end
    end
  end
end

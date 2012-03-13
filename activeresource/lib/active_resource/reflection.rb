require 'active_support/core_ext/class/attribute'
require 'active_support/core_ext/module/deprecation'

module ActiveResource
  # = Active Resource reflection
  #
  # Associations in ActiveResource would be used to resolve nested attributes
  # in a response with correct classes.
  # Now they could be specified over Associations with the options :class_name
  module Reflection # :nodoc:
    extend ActiveSupport::Concern

    included do
      class_attribute :reflections
      self.reflections = {}
    end

    module ClassMethods
      def create_reflection(macro, name, options)
        reflection = AssociationReflection.new(macro, name, options)
        self.reflections = self.reflections.merge(name => reflection)
        reflection
      end
    end


    class AssociationReflection

      def initialize(macro, name, options)
        @macro, @name, @options = macro, name, options
      end

      # Returns the name of the macro.
      #
      # <tt>has_many :clients</tt> returns <tt>:clients</tt>
      attr_reader :name

      # Returns the macro type.
      #
      # <tt>has_many :clients</tt> returns <tt>:has_many</tt>
      attr_reader :macro

      # Returns the hash of options used for the macro.
      #
      # <tt>has_many :clients</tt> returns +{}+
      attr_reader :options

      # Returns the class for the macro.
      #
      # <tt>has_many :clients</tt> returns the Client class
      def klass
        @klass ||= class_name.constantize
      end

      # Returns the class name for the macro.
      #
      # <tt>has_many :clients</tt> returns <tt>'Client'</tt>
      def class_name
        @class_name ||= derive_class_name
      end

      # Returns the foreign_key for the macro.
      def foreign_key
        @foreign_key ||= self.options[:foreign_key] || "#{self.name.to_s.downcase}_id"
      end

      private
      def derive_class_name
        return (options[:class_name] ? options[:class_name].to_s : name.to_s).classify
      end

      def derive_foreign_key
        return options[:foreign_key] ? options[:foreign_key].to_s : "#{name.to_s.downcase}_id"
      end
    end
  end
end

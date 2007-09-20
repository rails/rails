module ActiveRecord #:nodoc:
  module Serialization
    class Serializer #:nodoc:
      attr_reader :options
    
      def initialize(record, options = {})
        @record, @options = record, options.dup
      end

      # To replicate the behavior in ActiveRecord#attributes,
      # :except takes precedence over :only.  If :only is not set
      # for a N level model but is set for the N+1 level models,
      # then because :except is set to a default value, the second
      # level model can have both :except and :only set.  So if
      # :only is set, always delete :except.
      def serializable_attribute_names
        attribute_names = @record.attribute_names

        if options[:only]
          options.delete(:except)
          attribute_names = attribute_names & Array(options[:only]).collect { |n| n.to_s }
        else
          options[:except] = Array(options[:except]) | Array(@record.class.inheritance_column)
          attribute_names = attribute_names - options[:except].collect { |n| n.to_s }
        end
      
        attribute_names
      end

      def serializable_method_names
        Array(options[:methods]).inject([]) do |method_attributes, name|
          method_attributes << :name if @record.respond_to?(name.to_s)
          method_attributes
        end
      end
      
      def serializable_names
        serializable_attribute_names + serializable_method_names
      end

      def serializable_record
        returning(serializable_record = {}) do
          serializable_names.each { |name| serializable_record[name] = @record.send(name) }
        end
      end

      def serialize
        # overwrite to implement
      end        
    
      def to_s(&block)
        serialize(&block)
      end
    end
  end
end

require 'active_record/serializers/xml_serializer'
require 'active_record/serializers/json_serializer'
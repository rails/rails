require 'active_support/json'

module ActiveRecord #:nodoc:
  module Serialization
    class Serializer #:nodoc:
      attr_reader :options

      def initialize(record, options = nil)
        @record = record
        @options = options ? options.dup : {}
      end

      # To replicate the behavior in ActiveRecord#attributes,
      # <tt>:except</tt> takes precedence over <tt>:only</tt>.  If <tt>:only</tt> is not set
      # for a N level model but is set for the N+1 level models,
      # then because <tt>:except</tt> is set to a default value, the second
      # level model can have both <tt>:except</tt> and <tt>:only</tt> set.  So if
      # <tt>:only</tt> is set, always delete <tt>:except</tt>.
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
          method_attributes << name if @record.respond_to?(name.to_s)
          method_attributes
        end
      end

      def serializable_names
        serializable_attribute_names + serializable_method_names
      end

      # Add associations specified via the <tt>:includes</tt> option.
      # Expects a block that takes as arguments:
      #   +association+ - name of the association
      #   +records+     - the association record(s) to be serialized
      #   +opts+        - options for the association records
      def add_includes(&block)
        if include_associations = options.delete(:include)
          base_only_or_except = { :except => options[:except],
                                  :only => options[:only] }

          include_has_options = include_associations.is_a?(Hash)
          associations = include_has_options ? include_associations.keys : Array(include_associations)

          for association in associations
            records = case @record.class.reflect_on_association(association).macro
            when :has_many, :has_and_belongs_to_many
              @record.send(association).to_a
            when :has_one, :belongs_to
              @record.send(association)
            end

            unless records.nil?
              association_options = include_has_options ? include_associations[association] : base_only_or_except
              opts = options.merge(association_options)
              yield(association, records, opts)
            end
          end

          options[:include] = include_associations
        end
      end

      def serializable_record
        returning(serializable_record = {}) do
          serializable_names.each { |name| serializable_record[name] = @record.send(name) }
          add_includes do |association, records, opts|
            if records.is_a?(Enumerable)
              serializable_record[association] = records.collect { |r| self.class.new(r, opts).serializable_record }
            else
              serializable_record[association] = self.class.new(records, opts).serializable_record
            end
          end
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

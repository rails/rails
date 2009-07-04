module ActiveRecord #:nodoc:
  module Serialization
    module RecordSerializer #:nodoc:
      def initialize(*args)
        super
        options[:except] |= Array.wrap(@serializable.class.inheritance_column)
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
          associations = include_has_options ? include_associations.keys : Array.wrap(include_associations)

          for association in associations
            records = case @serializable.class.reflect_on_association(association).macro
            when :has_many, :has_and_belongs_to_many
              @serializable.send(association).to_a
            when :has_one, :belongs_to
              @serializable.send(association)
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

      def serializable_hash
        hash = super

        add_includes do |association, records, opts|
          hash[association] =
            if records.is_a?(Enumerable)
              records.collect { |r| self.class.new(r, opts).serializable_hash }
            else
              self.class.new(records, opts).serializable_hash
            end
        end

        hash
      end
    end
  end
end

require 'active_record/serializers/xml_serializer'
require 'active_record/serializers/json_serializer'

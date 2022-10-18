# frozen_string_literal: true

module ActiveModel
  module Type
    class Value
    end

    class Document < Value
      attr_reader :document_class, :cast_type
      attr_reader :collection
      attr_reader :context

      def initialize(class_name: nil, cast_type: nil, collection: false, context: nil)
        @document_class = resolve_constant class_name, from: context if class_name
        @cast_type      = lookup_or_return cast_type if cast_type
        @collection     = collection
        @context        = context
      end

      def collection?
        collection
      end

      def default_collection?
        collection == true
      end

      def collection_class
        return unless collection?

        if default_collection?
          @collection_class ||= ActiveModel::Embedding::Collection
        else
          @collection_class ||= resolve_constant collection, from: context
        end
      end

      def cast(value)
        return unless value

        if collection?
          return value if value.respond_to? :document_class

          documents = value.map { |attributes| process attributes }

          collection_class.new(documents)
        else
          return value if value.respond_to? :id

          process value
        end
      end

      def process(value)
        cast_type ? cast_type.cast(value) : document_class.new(value)
      end

      def serialize(value)
        value.to_json
      end

      def deserialize(json)
        return unless json

        value = ActiveSupport::JSON.decode(json)

        cast value
      end

      def changed_in_place?(old_value, new_value)
        deserialize(old_value) != new_value
      end

      private
        def resolve_constant(name, from: nil)
          name = clean_scope(name)

          if from
            context = from.split("::")

            context.each do
              scope    = context.join("::")
              constant = "::#{scope}::#{name}".constantize rescue nil

              return constant if constant

              context.pop
            end
          end

          "::#{name}".constantize
        end

        def clean_scope(name)
          name.gsub(/^::/, "")
        end

        def lookup_or_return(cast_type)
          case cast_type
          when Symbol
            begin
              Type.lookup(cast_type)
            rescue
              ActiveRecord::Type.lookup(cast_type)
            end
          else
            cast_type
          end
        end
    end
  end
end

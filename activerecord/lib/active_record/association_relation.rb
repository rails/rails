# frozen_string_literal: true

module ActiveRecord
  class AssociationRelation < Relation # :nodoc:
    def initialize(klass, association, **)
      super(klass)
      @association = association
    end

    def proxy_association
      @association
    end

    def ==(other)
      other == records
    end

    %w(insert insert_all insert! insert_all! upsert upsert_all).each do |method|
      class_eval <<~RUBY, __FILE__, __LINE__ + 1
        def #{method}(attributes, **kwargs)
          if @association.reflection.through_reflection?
            raise ArgumentError, "Bulk insert or upsert is currently not supported for has_many through association"
          end

          super
        end
      RUBY
    end

    private
      def _new(attributes, &block)
        @association.build(attributes, &block)
      end

      def _create(attributes, &block)
        @association.create(attributes, &block)
      end

      def _create!(attributes, &block)
        @association.create!(attributes, &block)
      end

      def exec_queries
        super do |record|
          @association.set_inverse_instance_from_queries(record)
          @association.set_strict_loading(record)
          yield record if block_given?
        end
      end
  end
end

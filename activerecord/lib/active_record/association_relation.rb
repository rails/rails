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
      class_eval <<~RUBY
        def #{method}(attributes, **kwargs)
          if @association.reflection.through_reflection?
            raise ArgumentError, "Bulk insert or upsert is currently not supported for has_many through association"
          end

          scoping { klass.#{method}(attributes, **kwargs) }
        end
      RUBY
    end

    def build(attributes = nil, &block)
      if attributes.is_a?(Array)
        attributes.collect { |attr| build(attr, &block) }
      else
        block = current_scope_restoring_block(&block)
        scoping { _new(attributes, &block) }
      end
    end
    alias new build

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
          yield record if block_given?
        end
      end
  end
end

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

    def insert(...)
      ensure_bulk_insert_or_upsert_supported!

      super
    end

    def insert_all(...)
      ensure_bulk_insert_or_upsert_supported!

      super
    end

    def insert!(...)
      ensure_bulk_insert_or_upsert_supported!

      super
    end

    def insert_all!(...)
      ensure_bulk_insert_or_upsert_supported!

      super
    end

    def upsert(...)
      ensure_bulk_insert_or_upsert_supported!

      super
    end

    def upsert_all(...)
      ensure_bulk_insert_or_upsert_supported!

      super
    end

    private
      def ensure_bulk_insert_or_upsert_supported!
        if @association.reflection.through_reflection?
          raise ArgumentError, "Bulk insert or upsert is currently not supported for has_many through association"
        end
      end

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

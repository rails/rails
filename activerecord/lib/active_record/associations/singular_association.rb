module ActiveRecord
  module Associations
    class SingularAssociation < Association #:nodoc:
      # Implements the reader method, e.g. foo.bar for Foo.has_one :bar
      def reader(force_reload = false)
        if force_reload
          klass.uncached { reload }
        elsif !loaded? || stale_target?
          reload
        end

        target
      end

      # Implements the writer method, e.g. foo.items= for Foo.has_many :items
      def writer(record)
        replace(record)
      end

      def create(attributes = {}, options = {}, &block)
        create_record(attributes, options, &block)
      end

      def create!(attributes = {}, options = {}, &block)
        create_record(attributes, options, true, &block)
      end

      def build(attributes = {}, options = {})
        record = build_record(attributes, options)
        yield(record) if block_given?
        set_new_record(record)
        record
      end

      private

        def create_scope
          scoped.scope_for_create.stringify_keys.except(klass.primary_key)
        end

        def find_target
          scoped.first.tap { |record| set_inverse_instance(record) }
        end

        # Implemented by subclasses
        def replace(record)
          raise NotImplementedError, "Subclasses must implement a replace(record) method"
        end

        def set_new_record(record)
          replace(record)
        end

        def create_record(attributes, options, raise_error = false)
          record = build_record(attributes, options)
          yield(record) if block_given?
          saved = record.save
          set_new_record(record)
          raise RecordInvalid.new(record) if !saved && raise_error
          record
        end
    end
  end
end

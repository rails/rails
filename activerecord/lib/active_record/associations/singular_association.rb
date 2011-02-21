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

      def create(attributes = {})
        new_record(:create, attributes)
      end

      def create!(attributes = {})
        build(attributes).tap { |record| record.save! }
      end

      def build(attributes = {})
        new_record(:build, attributes)
      end

      private

        def find_target
          scoped.first.tap { |record| set_inverse_instance(record) }
        end

        # Implemented by subclasses
        def replace(record)
          raise NotImplementedError
        end

        def set_new_record(record)
          replace(record)
        end

        def new_record(method, attributes)
          attributes = scoped.scope_for_create.merge(attributes || {})
          record = reflection.send("#{method}_association", attributes)
          set_new_record(record)
          record
        end
    end
  end
end

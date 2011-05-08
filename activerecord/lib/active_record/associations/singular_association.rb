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

      def create(attributes = {}, options = {})
        new_record(:create, attributes, options)
      end

      def create!(attributes = {}, options = {})
        build(attributes, options).tap { |record| record.save! }
      end

      def build(attributes = {}, options = {})
        new_record(:build, attributes, options)
      end

      private

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

        def new_record(method, attributes, options)
          attributes = scoped.scope_for_create.merge(attributes || {})
          record = reflection.send("#{method}_association", attributes, options)
          set_new_record(record)
          record
        end
    end
  end
end

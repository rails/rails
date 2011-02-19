module ActiveRecord
  module Associations
    class SingularAssociation < Association #:nodoc:
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

        def check_record(record)
          record = record.target if Association === record
          raise_on_type_mismatch(record) if record
          record
        end

        def new_record(method, attributes)
          attributes = scoped.scope_for_create.merge(attributes || {})
          record = @reflection.send("#{method}_association", attributes)
          set_new_record(record)
          record
        end
    end
  end
end

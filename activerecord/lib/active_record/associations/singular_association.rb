module ActiveRecord
  module Associations
    class SingularAssociation < AssociationProxy #:nodoc:
      def create(attributes = {})
        record = scoped.scoping { @reflection.create_association(attributes) }
        set_new_record(record)
        record
      end

      def create!(attributes = {})
        build(attributes).tap { |record| record.save! }
      end

      def build(attributes = {})
        record = scoped.scoping { @reflection.build_association(attributes) }
        set_new_record(record)
        record
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
          record = record.target if AssociationProxy === record
          raise_on_type_mismatch(record) if record
          record
        end
    end
  end
end

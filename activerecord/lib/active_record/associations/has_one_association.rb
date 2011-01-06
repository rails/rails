module ActiveRecord
  # = Active Record Belongs To Has One Association
  module Associations
    class HasOneAssociation < AssociationProxy #:nodoc:
      def create(attributes = {})
        new_record(:create_association, attributes)
      end

      def create!(attributes = {})
        new_record(:create_association!, attributes)
      end

      def build(attributes = {})
        new_record(:build_association, attributes)
      end

      def replace(obj, save = true)
        load_target

        unless @target.nil? || @target == obj
          if @reflection.options[:dependent] && save
            case @reflection.options[:dependent]
            when :delete
              @target.delete if @target.persisted?
            when :destroy
              @target.destroy if @target.persisted?
            when :nullify
              @target[@reflection.foreign_key] = nil
              @target.save if @owner.persisted? && @target.persisted?
            end
          else
            @target[@reflection.foreign_key] = nil
            @target.save if @owner.persisted? && @target.persisted?
          end
        end

        if obj.nil?
          @target = nil
        else
          raise_on_type_mismatch(obj)
          set_owner_attributes(obj)
          @target = (AssociationProxy === obj ? obj.target : obj)
        end

        set_inverse_instance(obj)
        loaded

        unless !@owner.persisted? || obj.nil? || !save
          return (obj.save ? self : false)
        else
          return (obj.nil? ? nil : self)
        end
      end

      private
        def find_target
          scoped.first.tap { |record| set_inverse_instance(record) }
        end

        def association_scope
          super.order(@reflection.options[:order])
        end

        alias creation_attributes construct_owner_attributes

        def new_record(method, attributes)
          record = scoped.scoping { @reflection.send(method, attributes) }
          replace(record, false)
          record
        end
    end
  end
end

module ActiveRecord
  # = Active Record Belongs To Has One Association
  module Associations
    class HasOneAssociation < AssociationProxy #:nodoc:
      include HasAssociation

      def create(attrs = {})
        new_record do |reflection|
          attrs = merge_with_conditions(attrs)
          reflection.create_association(attrs)
        end
      end

      def create!(attrs = {})
        new_record do |reflection|
          attrs = merge_with_conditions(attrs)
          reflection.create_association!(attrs)
        end
      end

      def build(attrs = {})
        new_record do |reflection|
          attrs = merge_with_conditions(attrs)
          reflection.build_association(attrs)
        end
      end

      def replace(obj, dont_save = false)
        load_target

        unless @target.nil? || @target == obj
          if @reflection.options[:dependent] && !dont_save
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

        unless !@owner.persisted? || obj.nil? || dont_save
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

        def new_record
          record = scoped.scoping { yield @reflection }
          replace(record, true)
          record
        end

        def merge_with_conditions(attrs={})
          attrs ||= {}
          attrs.update(@reflection.options[:conditions]) if @reflection.options[:conditions].is_a?(Hash)
          attrs
        end
    end
  end
end

module ActiveRecord
  # = Active Record Belongs To Has One Association
  module Associations
    class HasOneAssociation < AssociationProxy #:nodoc:
      include HasAssociation

      def create(attrs = {}, replace_existing = true)
        new_record(replace_existing) do |reflection|
          attrs = merge_with_conditions(attrs)
          reflection.create_association(attrs)
        end
      end

      def create!(attrs = {}, replace_existing = true)
        new_record(replace_existing) do |reflection|
          attrs = merge_with_conditions(attrs)
          reflection.create_association!(attrs)
        end
      end

      def build(attrs = {}, replace_existing = true)
        new_record(replace_existing) do |reflection|
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
          options = @reflection.options.dup.slice(:select, :order, :include, :readonly)

          the_target = with_scope(:find => @scope[:find]) do
            @reflection.klass.find(:first, options)
          end
          set_inverse_instance(the_target)
          the_target
        end

        def construct_find_scope
          { :conditions => construct_conditions }
        end

        def construct_create_scope
          construct_owner_attributes
        end

        def new_record(replace_existing)
          # Make sure we load the target first, if we plan on replacing the existing
          # instance. Otherwise, if the target has not previously been loaded
          # elsewhere, the instance we create will get orphaned.
          load_target if replace_existing
          record = @reflection.klass.send(:with_scope, :create => @scope[:create]) do
            yield @reflection
          end

          if replace_existing
            replace(record, true)
          else
            record[@reflection.foreign_key] = @owner.id if @owner.persisted?
            self.target = record
            set_inverse_instance(record)
          end

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

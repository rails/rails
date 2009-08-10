require 'active_support/core_ext/object/tap'

module ActiveRecord
  module AttributeMethods
    module Dirty
      extend ActiveSupport::Concern
      include ActiveModel::Dirty

      included do
        alias_method_chain :save,   :dirty
        alias_method_chain :save!,  :dirty
        alias_method_chain :update, :dirty
        alias_method_chain :reload, :dirty

        superclass_delegating_accessor :partial_updates
        self.partial_updates = true
      end

      # Attempts to +save+ the record and clears changed attributes if successful.
      def save_with_dirty(*args) #:nodoc:
        if status = save_without_dirty(*args)
          changed_attributes.clear
        end
        status
      end

      # Attempts to <tt>save!</tt> the record and clears changed attributes if successful.
      def save_with_dirty!(*args) #:nodoc:
        save_without_dirty!(*args).tap { changed_attributes.clear }
      end

      # <tt>reload</tt> the record and clears changed attributes.
      def reload_with_dirty(*args) #:nodoc:
        reload_without_dirty(*args).tap { changed_attributes.clear }
      end

      private
        # Wrap write_attribute to remember original attribute value.
        def write_attribute(attr, value)
          attr = attr.to_s

          # The attribute already has an unsaved change.
          if changed_attributes.include?(attr)
            old = changed_attributes[attr]
            changed_attributes.delete(attr) unless field_changed?(attr, old, value)
          else
            old = clone_attribute_value(:read_attribute, attr)
            changed_attributes[attr] = old if field_changed?(attr, old, value)
          end

          # Carry on.
          super(attr, value)
        end

        def update_with_dirty
          if partial_updates?
            # Serialized attributes should always be written in case they've been
            # changed in place.
            update_without_dirty(changed | (attributes.keys & self.class.serialized_attributes.keys))
          else
            update_without_dirty
          end
        end

        def field_changed?(attr, old, value)
          if column = column_for_attribute(attr)
            if column.number? && column.null && (old.nil? || old == 0) && value.blank?
              # For nullable numeric columns, NULL gets stored in database for blank (i.e. '') values.
              # Hence we don't record it as a change if the value changes from nil to ''.
              # If an old value of 0 is set to '' we want this to get changed to nil as otherwise it'll
              # be typecast back to 0 (''.to_i => 0)
              value = nil
            else
              value = column.type_cast(value)
            end
          end

          old != value
        end
    end
  end
end

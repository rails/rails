# frozen_string_literal: true

module ActiveRecord::Associations
  module ForeignAssociation # :nodoc:
    def foreign_key_present?
      if reflection.klass.primary_key
        owner.attribute_present?(reflection.active_record_primary_key)
      else
        false
      end
    end

    def nullified_owner_attributes
      Hash.new.tap do |attrs|
        attrs[reflection.foreign_key] = nil
        attrs[reflection.type] = nil if reflection.type.present?
      end
    end

    private
      # Sets the owner attributes on the given record
      def set_owner_attributes(record)
        return if options[:through]

        key = owner._read_attribute(reflection.join_foreign_key)
        record._write_attribute(reflection.join_primary_key, key)

        if reflection.type
          record._write_attribute(reflection.type, owner.class.polymorphic_name)
        end
      end
  end
end

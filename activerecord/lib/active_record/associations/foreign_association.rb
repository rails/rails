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
        Array(reflection.foreign_key).each { |foreign_key| attrs[foreign_key] = nil }
        attrs[reflection.type] = nil if reflection.type.present?
      end
    end

    private
      # Sets the owner attributes on the given record
      def set_owner_attributes(record)
        return if options[:through]

        primary_key_attribute_names = Array(reflection.join_primary_key)
        foreign_key_attribute_names = Array(reflection.join_foreign_key)

        primary_key_foreign_key_pairs = primary_key_attribute_names.zip(foreign_key_attribute_names)

        primary_key_foreign_key_pairs.each do |primary_key, foreign_key|
          value = owner._read_attribute(foreign_key)
          record._write_attribute(primary_key, value)
        end

        if reflection.type
          record._write_attribute(reflection.type, owner.class.polymorphic_name)
        end
      end
  end
end

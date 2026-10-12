# frozen_string_literal: true

module ActiveRecord::Associations
  module ForeignAssociation # :nodoc:
    def foreign_key_present?
      if reflection.klass.primary_key
        ActiveRecord::Key.for(reflection.active_record_primary_key).all? do |key|
          owner.attribute_present?(key)
        end
      else
        false
      end
    end

    def nullified_owner_attributes
      Hash.new.tap do |attrs|
        ActiveRecord::Key.for(reflection.foreign_key).each { |foreign_key| attrs[foreign_key] = nil }
        attrs[reflection.type] = nil if reflection.type.present?
      end
    end

    private
      # Sets the owner attributes on the given record
      def set_owner_attributes(record)
        return if options[:through]

        reflection.query_key_mapping.foreign_key_pairs.each do |active_record_column, associated_record_column|
          value = owner.read_attribute(active_record_column)
          record.write_attribute(associated_record_column, value)
        end

        if reflection.type
          record.write_attribute(reflection.type, owner.class.polymorphic_name)
        end
      end
  end
end

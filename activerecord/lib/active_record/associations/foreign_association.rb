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

        primary_key_attribute_names = ActiveRecord::Key.for(reflection.join_primary_key)
        foreign_key_attribute_names = ActiveRecord::Key.for(reflection.join_foreign_key)

        primary_key_foreign_key_pairs = primary_key_attribute_names.zip(foreign_key_attribute_names)

        primary_key_foreign_key_pairs.each do |primary_key, foreign_key|
          value = owner.read_attribute(foreign_key)
          record.write_attribute(primary_key, value)
        end

        if reflection.type
          record.write_attribute(reflection.type, owner.class.polymorphic_name)
        end
      end
  end
end

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
  end
end

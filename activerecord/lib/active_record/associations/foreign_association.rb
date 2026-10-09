# frozen_string_literal: true

# :markup: markdown
module ActiveRecord::Associations
  module ForeignAssociation # :nodoc:
    def foreign_key_present?
      if reflection.klass.primary_key
        route = reflection.association_route(origin_class: owner.class, destination_class: klass)
        route.reference_origin_key.all? { |key| owner.attribute_present?(key) }
      else
        false
      end
    end

    def nullified_owner_attributes
      Hash.new.tap do |attrs|
        reflection.foreign_key_definition.each { |foreign_key| attrs[foreign_key] = nil }
        attrs[reflection.type] = nil if reflection.type.present?
      end
    end

    private
      # Sets the owner attributes on the given record
      def set_owner_attributes(record)
        return if options[:through]

        primary_key_attribute_names = reflection.join_primary_key_definition
        foreign_key_attribute_names = reflection.join_foreign_key_definition

        primary_key_foreign_key_pairs = primary_key_attribute_names.zip(foreign_key_attribute_names)

        primary_key_foreign_key_pairs.each do |primary_key, foreign_key|
          value = owner.read_attr(foreign_key)
          record.write_attribute(primary_key, value)
        end

        if reflection.type
          record.write_attribute(reflection.type, owner.class.polymorphic_name)
        end
      end
  end
end

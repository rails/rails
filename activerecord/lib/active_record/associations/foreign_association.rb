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
      route = reflection.association_route(origin_class: owner.class, destination_class: klass)
      route.reference_destination_key.index_with(nil).merge!(route.destination_fixed_values.transform_values { nil })
    end

    private
      # Sets the owner attributes on the given record
      def set_owner_attributes(record)
        return if options[:through]

        reflection.association_route(origin_class: owner.class, destination_class: record.class).write(owner, record)
      end
  end
end

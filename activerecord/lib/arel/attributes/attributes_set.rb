# frozen_string_literal: true

module Arel # :nodoc: all
  module Attributes
    class AttributesSet < Struct.new :relation, :names
      def type_caster_by_name
        @type_caster_by_name ||= names.index_with do |name|
          relation.type_for_attribute(name)
        end
      end
    end
  end

  AttributesSet = Attributes::AttributesSet
end

# frozen_string_literal: true

module ActiveRecord
  class PredicateBuilder
    # Handles +Arel.array_bind+ values. Reuses +ArrayHandler+ nil/range logic
    # and builds a +HomogeneousArrayBind+ node so adapters can send the list as
    # a single array parameter.
    class ArrayBindHandler < ArrayHandler # :nodoc:
      def call(attribute, value)
        super(attribute, value.values)
      end

      private
        def homogeneous_in(values, attribute)
          Arel::Nodes::HomogeneousArrayBind.new(values, attribute, :in)
        end
    end
  end
end

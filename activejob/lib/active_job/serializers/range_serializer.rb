# frozen_string_literal: true

module ActiveJob
  module Serializers
    class RangeSerializer < ObjectSerializer
      def serialize(range)
        super(
          "begin" => Arguments.serialize_argument(range.begin),
          "end" => Arguments.serialize_argument(range.end),
          "exclude_end" => range.exclude_end?, # Always boolean, no need to serialize
        )
      end

      def deserialize(hash)
        Range.new(*Arguments.deserialize([hash["begin"], hash["end"]]), hash["exclude_end"])
      end

      def klass
        ::Range
      end
    end
  end
end

# frozen_string_literal: true

module ActiveJob
  module Serializers
    class RangeSerializer < ObjectSerializer
      KEYS = %w[begin end exclude_end].freeze

      def serialize(range)
        args = Arguments.serialize([range.begin, range.end, range.exclude_end?])
        hash = KEYS.zip(args).to_h
        super(hash)
      end

      def deserialize(hash)
        args = Arguments.deserialize(hash.values_at(*KEYS))
        Range.new(*args)
      end

      private
        def klass
          ::Range
        end
    end
  end
end

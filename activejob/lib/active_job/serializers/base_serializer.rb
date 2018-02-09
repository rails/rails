# frozen_string_literal: true

module ActiveJob
  module Serializers
    class BaseSerializer
      class << self
        def serialize?(argument)
          argument.is_a?(klass)
        end

        def deserialize?(_argument)
          raise NotImplementedError
        end

        def serialize(_argument)
          raise NotImplementedError
        end

        def deserialize(_argument)
          raise NotImplementedError
        end

        private

        def klass
          raise NotImplementedError
        end
      end
    end
  end
end

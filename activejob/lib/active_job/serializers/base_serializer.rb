# frozen_string_literal: true

module ActiveJob
  module Serializers
    class BaseSerializer
      class << self
        def serialize?(argument)
          argument.is_a?(klass)
        end
      end
    end
  end
end

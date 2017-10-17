# frozen_string_literal: true

module ActiveJob
  module Serializers
    # Provides methods to serialize and deserialize `Class` (`ActiveRecord::Base`, `MySpecialService`, ...)
    class ClassSerializer < ObjectSerializer
      class << self
        def serialize(argument_klass)
          { key => "::#{argument_klass.name}" }
        end

        def key
          "_aj_class"
        end

        private

        def klass
          ::Class
        end
      end
    end
  end
end

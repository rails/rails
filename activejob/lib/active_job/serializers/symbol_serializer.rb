# frozen_string_literal: true

module ActiveJob
  module Serializers
    # Provides methods to serialize and deserialize `Symbol` (`:foo`, `:bar`, ...)
    class SymbolSerializer < ObjectSerializer
      class << self
        def serialize(symbol)
          { key => symbol.to_s }
        end

        def deserialize(hash)
          hash[key].to_sym
        end

        def key
          "_aj_symbol"
        end

        private

        def klass
          ::Symbol
        end
      end
    end
  end
end

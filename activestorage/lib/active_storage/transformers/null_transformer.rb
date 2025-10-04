# frozen_string_literal: true

module ActiveStorage
  module Transformers
    class NullTransformer < Transformer # :nodoc:
      private
        def process(file, format:)
          file
        end
    end
  end
end

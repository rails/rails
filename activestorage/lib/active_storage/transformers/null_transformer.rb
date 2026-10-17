# frozen_string_literal: true

# :markup: markdown
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

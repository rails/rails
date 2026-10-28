# frozen_string_literal: true

# :markup: markdown
module Arel # :nodoc: all
  module AliasPredication
    def as(other)
      other = other.name if other.is_a?(Symbol)

      Nodes::As.new self, Nodes::SqlLiteral.new(other, retryable: true)
    end
  end
end

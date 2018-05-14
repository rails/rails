# frozen_string_literal: true

module Arel # :nodoc: all
  module AliasPredication
    def as(other)
      Nodes::As.new self, Nodes::SqlLiteral.new(other)
    end
  end
end

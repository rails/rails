# frozen_string_literal: true

module Monads # :nodoc:
  class Many # :nodoc:
    attr_reader :values

    def initialize(values)
      @values = values
    end

    def try(&block)
      Many.new(values.map(&block).flat_map(&:values))
    end

    def method_missing(*args, &block)
      try do |value|
        Many.new(value.public_send(*args, &block))
      end
    end
  end
end

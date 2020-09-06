# frozen_string_literal: true

require 'active_model/error'
require 'forwardable'

module ActiveModel
  class NestedError < Error
    def initialize(base, inner_error, override_options = {})
      @base = base
      @inner_error = inner_error
      @attribute = override_options.fetch(:attribute) { inner_error.attribute }
      @type = override_options.fetch(:type) { inner_error.type }
      @raw_type = inner_error.raw_type
      @options = inner_error.options
    end

    attr_reader :inner_error

    extend Forwardable
    def_delegators :@inner_error, :message
  end
end

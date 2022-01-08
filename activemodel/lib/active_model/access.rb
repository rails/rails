# frozen_string_literal: true

require "active_support/core_ext/enumerable"
require "active_support/core_ext/hash/indifferent_access"

module ActiveModel
  module Access # :nodoc:
    def slice(*methods)
      methods.flatten.index_with { |method| public_send(method) }.with_indifferent_access
    end

    def values_at(*methods)
      methods.flatten.map! { |method| public_send(method) }
    end
  end
end

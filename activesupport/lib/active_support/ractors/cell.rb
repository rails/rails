# frozen_string_literal: true

module ActiveSupport
  module Ractors
    # Modules are shareable without being frozen, so the main Ractor can
    # replace this cell's value after an object holding it is made shareable.
    class Cell < Module # :nodoc:
      attr_accessor :value
    end
  end
end

# frozen_string_literal: true

require "active_model/type/integer"

module ActiveModel
  module Type
    class BigInteger < Integer # :nodoc:
      private
        def after_max_value
          ::Float::INFINITY
        end
    end
  end
end

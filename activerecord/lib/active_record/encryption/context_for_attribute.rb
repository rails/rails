# frozen_string_literal: true

module ActiveRecord
  module Encryption
    class ContextForAttribute < Context
      def merge(other) # :nodoc:
        assign_properties(other.non_defaults)
      end
    end
  end
end

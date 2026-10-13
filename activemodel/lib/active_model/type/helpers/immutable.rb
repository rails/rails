# frozen_string_literal: true

# :markup: markdown
module ActiveModel
  module Type
    module Helpers # :nodoc: all
      module Immutable
        def mutable? # :nodoc:
          false
        end
      end
    end
  end
end

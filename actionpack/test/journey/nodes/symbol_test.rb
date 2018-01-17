# frozen_string_literal: true

require "abstract_unit"

module ActionDispatch
  module Journey
    module Nodes
      class TestSymbol < ActiveSupport::TestCase
        def test_default_regexp?
          sym = Symbol.new "foo"
          assert sym.default_regexp?

          sym.regexp = nil
          assert_not sym.default_regexp?
        end
      end
    end
  end
end

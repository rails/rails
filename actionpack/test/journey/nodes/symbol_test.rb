require 'abstract_unit'

module ActionDispatch
  module Journey
    module Nodes
      class TestSymbol < MiniTest::Unit::TestCase
        def test_default_regexp?
          sym = Symbol.new nil
          assert sym.default_regexp?

          sym.regexp = nil
          refute sym.default_regexp?
        end
      end
    end
  end
end

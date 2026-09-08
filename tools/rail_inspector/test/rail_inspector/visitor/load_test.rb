# frozen_string_literal: true

require "test_helper"
require "rail_inspector/visitor/load"

class LoadTest < Minitest::Test
  def test_finds_requires_and_autoloads
    source = <<~FILE
    require "a"
    require "b"

    module D
      require "k"

      autoload :L
      autoload :M, "n/o"

      class E::F
        require "p/q"

        autoload :G
        autoload :H, "i/j"
      end
    end
    FILE

    loads = { requires: [], autoloads: [] }

    visitor = RailInspector::Visitor::Load.new { loads }
    Prism.parse(source).value.accept(visitor)

    assert_equal ["a", "b", "k", "p/q"], loads[:requires]
    assert_equal ["d/l", "n/o", "d/e/f/g", "i/j"], loads[:autoloads]
  end
end

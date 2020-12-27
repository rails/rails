# frozen_string_literal: true

require_relative "abstract_unit"
require "active_support/constant_resolver"

module WhereAreMyKeys
  module School
    class Classroom
      # ...
    end

    class Cafetaria
      # ...
    end
  end

  module Home
    class Kitchen
      # ...
    end

    class Basement
      # ...

      class Keys
        def self.found?
          true
        end
      end
    end
  end

  module Club
    # ...
  end
end

class ConstantResolverTest < ActiveSupport::TestCase
  def test_constant_resolver_should_be_prepended
    class_ancestors = Class.ancestors
    module_ancestors = Module.ancestors

    assert_equal ConstantResolver, class_ancestors.first
    assert_equal ConstantResolver, module_ancestors.first
  end

  def test_should_resolve_a_partial_constant_name
    assert_equal WhereAreMyKeys::Home::Basement::Keys, WhereAreMyKeys::Keys
    assert_equal true, WhereAreMyKeys::Keys.found?
  end
end

# frozen_string_literal: true

require_relative "abstract_unit"
require "active_support/constant_resolver"

module WhereAreMyKeys
  module School
    class Classroom
      # ...
    end

    class Cafeteria
      # ...
    end
  end

  module Club
    # ...
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
end

module Empty
end

class ConstantResolverTest < ActiveSupport::TestCase
  def test_should_be_prepended
    class_ancestors = Class.ancestors
    module_ancestors = Module.ancestors

    assert_equal ConstantResolver, class_ancestors.first
    assert_equal ConstantResolver, module_ancestors.first
  end

  def test_should_resolve_a_partial_constant_name
    assert_equal WhereAreMyKeys::Home::Basement::Keys, WhereAreMyKeys::Keys
    assert WhereAreMyKeys::Keys.found?
  end

  def test_should_preserve_the_default_behaviour_if_self_is_object_class
    assert_raise(NameError) { yield Object::Keys }
    assert Object::NameError
  end

  def test_should_raise_a_name_error_if_constants_is_empty
    assert_raises(NameError) { yield Empty::Keys }
  end
end

require "abstract_unit"
require "active_support/core_ext/module/qualified_const"

module QualifiedConstTestMod
  X = false

  module M
    X = 1

    class C
      X = 2
    end
  end

  module N
    include M
  end
end

class QualifiedConstTest < ActiveSupport::TestCase
  test "qualified_const_set" do
    assert_deprecated do
      begin
        m = Module.new
        assert_equal m, Object.qualified_const_set("QualifiedConstTestMod2", m)
        assert_equal m, ::QualifiedConstTestMod2

        # We are going to assign to existing constants on purpose, so silence warnings.
        silence_warnings do
          assert_equal true, QualifiedConstTestMod.qualified_const_set("QualifiedConstTestMod::X", true)
          assert_equal true, QualifiedConstTestMod::X

          assert_equal 10, QualifiedConstTestMod::M.qualified_const_set("X", 10)
          assert_equal 10, QualifiedConstTestMod::M::X
        end
      ensure
        silence_warnings do
          QualifiedConstTestMod.qualified_const_set("QualifiedConstTestMod::X", false)
          QualifiedConstTestMod::M.qualified_const_set("X", 1)
        end
      end
    end
  end

  test "reject absolute paths" do
    assert_deprecated do
      assert_raise_with_message(NameError, "wrong constant name ::X") { Object.qualified_const_set("::X", nil) }
      assert_raise_with_message(NameError, "wrong constant name ::X") { Object.qualified_const_set("::X::Y", nil) }
    end
  end

  private

    def assert_raise_with_message(expected_exception, expected_message, &block)
      exception = assert_raise(expected_exception, &block)
      assert_equal expected_message, exception.message
    end
end

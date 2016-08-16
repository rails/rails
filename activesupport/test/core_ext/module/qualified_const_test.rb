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
  test "Object.qualified_const_defined?" do
    assert_deprecated do
      assert Object.qualified_const_defined?("QualifiedConstTestMod")
      assert !Object.qualified_const_defined?("NonExistingQualifiedConstTestMod")

      assert Object.qualified_const_defined?("QualifiedConstTestMod::X")
      assert !Object.qualified_const_defined?("QualifiedConstTestMod::Y")

      assert Object.qualified_const_defined?("QualifiedConstTestMod::M::X")
      assert !Object.qualified_const_defined?("QualifiedConstTestMod::M::Y")

      if Module.method(:const_defined?).arity == 1
        assert !Object.qualified_const_defined?("QualifiedConstTestMod::N::X")
      else
        assert Object.qualified_const_defined?("QualifiedConstTestMod::N::X")
        assert !Object.qualified_const_defined?("QualifiedConstTestMod::N::X", false)
        assert Object.qualified_const_defined?("QualifiedConstTestMod::N::X", true)
      end
    end
  end

  test "mod.qualified_const_defined?" do
    assert_deprecated do
      assert QualifiedConstTestMod.qualified_const_defined?("M")
      assert !QualifiedConstTestMod.qualified_const_defined?("NonExistingM")

      assert QualifiedConstTestMod.qualified_const_defined?("M::X")
      assert !QualifiedConstTestMod.qualified_const_defined?("M::Y")

      assert QualifiedConstTestMod.qualified_const_defined?("M::C::X")
      assert !QualifiedConstTestMod.qualified_const_defined?("M::C::Y")

      if Module.method(:const_defined?).arity == 1
        assert !QualifiedConstTestMod.qualified_const_defined?("QualifiedConstTestMod::N::X")
      else
        assert QualifiedConstTestMod.qualified_const_defined?("N::X")
        assert !QualifiedConstTestMod.qualified_const_defined?("N::X", false)
        assert QualifiedConstTestMod.qualified_const_defined?("N::X", true)
      end
    end
  end

  test "qualified_const_get" do
    assert_deprecated do
      assert_equal false, Object.qualified_const_get("QualifiedConstTestMod::X")
      assert_equal false, QualifiedConstTestMod.qualified_const_get("X")
      assert_equal 1, QualifiedConstTestMod.qualified_const_get("M::X")
      assert_equal 1, QualifiedConstTestMod.qualified_const_get("N::X")
      assert_equal 2, QualifiedConstTestMod.qualified_const_get("M::C::X")

      assert_raise(NameError) { QualifiedConstTestMod.qualified_const_get("M::C::Y") }
    end
  end

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
      assert_raise_with_message(NameError, "wrong constant name ::X") { Object.qualified_const_defined?("::X") }
      assert_raise_with_message(NameError, "wrong constant name ::X") { Object.qualified_const_defined?("::X::Y") }

      assert_raise_with_message(NameError, "wrong constant name ::X") { Object.qualified_const_get("::X") }
      assert_raise_with_message(NameError, "wrong constant name ::X") { Object.qualified_const_get("::X::Y") }

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

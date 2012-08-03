require 'abstract_unit'
require 'active_support/core_ext/object'

class PeekTest < ActiveSupport::TestCase
  class Sister
    class << self
      def inspect
        "My Sister"
      end

      def cute?
        false
      end

      def name
        "Kirino"
      end
    end
  end

  def test_peek_on_nil
    assert_equal "nil\n", capture(:stdout) { nil.peek }
  end

  def test_peek_on_class
    assert_equal "My Sister\n", capture(:stdout) { Sister.peek }
  end

  def test_peek_on_string
    assert_equal "\"Kirino\"\n", capture(:stdout) { Sister.name.peek }
  end

  def test_peek_chain
    assert_equal "false\n", capture(:stdout) {
      assert_equal "FALSE", Sister.cute?.peek.to_s.upcase
    }
  end
end

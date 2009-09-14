require 'active_support'
require 'test/unit'

class FlashCacheOnPrivateMemoizationTest < Test::Unit::TestCase
  extend ActiveSupport::Memoizable

  def test_public
    assert_method_unmemoizable :pub
  end

  def test_protected
    assert_method_unmemoizable :prot
  end

  def test_private
    assert_method_unmemoizable :priv
  end

  def pub; rand end
  memoize :pub

  protected

  def prot; rand end
  memoize :prot

  private

  def priv; rand end
  memoize :priv

  def assert_method_unmemoizable(meth, message=nil)
    full_message = build_message(message, "<?> not unmemoizable.\n", meth)
    assert_block(full_message) do
      a = send meth
      b = send meth
      unmemoize_all
      c = send meth
      a == b && a != c
    end
  end

end

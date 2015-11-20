class IndifferentHashEqualityTest < ActiveSupport::TestCase
  def setup
    @regular_hash = {foo: :bar}
    @indifferent_hash = ActiveSupport::HashWithIndifferentAccess.new(@regular_hash)
  end

  def test_equal
    assert @indifferent_hash.eql?(@regular_hash)
    assert_equal @indifferent_hash, @regular_hash
  end

  def test_equal_to_other_classes
    @indifferent_hash = ActiveSupport::HashWithIndifferentAccess.new(foo: :bar)
    assert_not_equal @indifferent_hash, 1
  end

  def test_hash_equal
    assert @regular_hash.eql?(@indifferent_hash)
    assert_equal @regular_hash, @indifferent_hash
  end
end

require 'abstract_unit'
require 'active_support/hash_with_indifferent_access'

class HashWithIndifferentAccessTest < ActiveSupport::TestCase
  def setup
    @hash = ActiveSupport::HashWithIndifferentAccess.new(name: 'ABC', 'occupation' => 'Designer')
  end

  test 'returns both string and symbol key values' do
    assert_equal 'ABC', @hash[:name]
    assert_equal 'ABC', @hash['name']
  end

  test 'returns the keys in the string form' do
    assert_equal ["name", "occupation"], @hash.keys
  end

  test 'responds to several Hash methods' do
    assert_respond_to @hash, :update
    assert_respond_to @hash, :key?
    assert_respond_to @hash, :fetch
    assert_respond_to @hash, :values_at
    assert_respond_to @hash, :dup
    assert_respond_to @hash, :merge
    assert_respond_to @hash, :reverse_merge
    assert_respond_to @hash, :reverse_merge!
    assert_respond_to @hash, :replace
    assert_respond_to @hash, :delete
    assert_respond_to @hash, :stringify_keys
    assert_respond_to @hash, :stringify_keys!
    assert_respond_to @hash, :deep_stringify_keys
    assert_respond_to @hash, :deep_stringify_keys!
    assert_respond_to @hash, :symbolize_keys
    assert_respond_to @hash, :select
    assert_respond_to @hash, :reject
    assert_respond_to @hash, :to_hash
  end

  test 'key?' do
    assert_equal true, @hash.key?(:name)
    assert_equal true, @hash.key?('name')
  end

  test 'fetch' do
    assert_equal 'ABC', @hash.fetch(:name)
    assert_equal 0, @hash.fetch('unknown_key', 0)
    assert_equal 0, @hash.fetch('unknown_key') { |key| 0 }
    assert_raises KeyError do
      @hash.fetch(:unknown_key)
    end
  end

  test 'values_at' do
    assert_equal ["ABC", "Designer"], @hash.values_at('name', :occupation)
  end
end
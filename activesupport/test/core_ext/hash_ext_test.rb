require 'test/unit'
require File.dirname(__FILE__) + '/../../lib/active_support/core_ext/hash'

class HashExtTest < Test::Unit::TestCase
  def setup
    
    @strings = { 'a' => 1, 'b' => 2 }
    @symbols = { :a  => 1, :b  => 2 }
    @mixed   = { :a  => 1, 'b' => 2 }
  end

  def test_methods
    h = {}
    assert_respond_to h, :symbolize_keys
    assert_respond_to h, :symbolize_keys!
    assert_respond_to h, :stringify_keys
    assert_respond_to h, :stringify_keys!
    assert_respond_to h, :to_options
    assert_respond_to h, :to_options!
  end

  def test_symbolize_keys
    assert_equal @symbols, @symbols.symbolize_keys
    assert_equal @symbols, @strings.symbolize_keys
    assert_equal @symbols, @mixed.symbolize_keys

    assert_raises(NoMethodError) { { [] => 1 }.symbolize_keys }
  end

  def test_symbolize_keys!
    assert_equal @symbols, @symbols.dup.symbolize_keys!
    assert_equal @symbols, @strings.dup.symbolize_keys!
    assert_equal @symbols, @mixed.dup.symbolize_keys!

    assert_raises(NoMethodError) { { [] => 1 }.symbolize_keys }
  end

  def test_stringify_keys
    assert_equal @strings, @symbols.stringify_keys
    assert_equal @strings, @strings.stringify_keys
    assert_equal @strings, @mixed.stringify_keys
  end

  def test_stringify_keys!
    assert_equal @strings, @symbols.dup.stringify_keys!
    assert_equal @strings, @strings.dup.stringify_keys!
    assert_equal @strings, @mixed.dup.stringify_keys!
  end

  def test_indifferent_assorted
    @strings = @strings.with_indifferent_access
    @symbols = @symbols.with_indifferent_access
    @mixed   = @mixed.with_indifferent_access
   
    assert_equal 'a', @strings.send(:convert_key, :a)
  
    assert_equal 1, @strings.fetch('a')
    assert_equal 1, @strings.fetch(:a.to_s)
    assert_equal 1, @strings.fetch(:a)
  
    hashes = { :@strings => @strings, :@symbols => @symbols, :@mixed => @mixed }
    method_map = { :'[]' => 1, :fetch => 1, :values_at => [1],
      :has_key? => true, :include? => true, :key? => true,
      :member? => true }
  
    hashes.each do |name, hash|
      method_map.sort_by { |m| m.to_s }.each do |meth, expected|
        assert_equal(expected, hash.send(meth, 'a'),
                     "Calling #{name}.#{meth} 'a'")
        assert_equal(expected, hash.send(meth, :a),
                     "Calling #{name}.#{meth} :a")
      end
    end
  
    assert_equal [1, 2], @strings.values_at('a', 'b')
    assert_equal [1, 2], @strings.values_at(:a, :b)
    assert_equal [1, 2], @symbols.values_at('a', 'b')
    assert_equal [1, 2], @symbols.values_at(:a, :b)
    assert_equal [1, 2], @mixed.values_at('a', 'b')
    assert_equal [1, 2], @mixed.values_at(:a, :b)
  end
  
  def test_indifferent_writing
    hash = HashWithIndifferentAccess.new
    hash[:a] = 1
    hash['b'] = 2
    hash[3] = 3
    
    assert_equal hash['a'], 1
    assert_equal hash['b'], 2
    assert_equal hash[:a], 1
    assert_equal hash[:b], 2
    assert_equal hash[3], 3
  end

  def test_assert_valid_keys
    assert_nothing_raised do
      { :failure => "stuff", :funny => "business" }.assert_valid_keys([ :failure, :funny ])
      { :failure => "stuff", :funny => "business" }.assert_valid_keys(:failure, :funny)
    end
    
    assert_raises(ArgumentError, "Unknown key(s): failore") do
      { :failore => "stuff", :funny => "business" }.assert_valid_keys([ :failure, :funny ])
      { :failore => "stuff", :funny => "business" }.assert_valid_keys(:failure, :funny)
    end
  end

  def test_indifferent_subhashes
    h = {'user' => {'id' => 5}}.with_indifferent_access
    ['user', :user].each {|user| [:id, 'id'].each {|id| assert_equal 5, h[user][id], "h[#{user.inspect}][#{id.inspect}] should be 5"}}
    
    h = {:user => {:id => 5}}.with_indifferent_access
    ['user', :user].each {|user| [:id, 'id'].each {|id| assert_equal 5, h[user][id], "h[#{user.inspect}][#{id.inspect}] should be 5"}}
  end

  def test_assorted_keys_not_stringified
    original = {Object.new => 2, 1 => 2, [] => true}
    indiff = original.with_indifferent_access
    assert(!indiff.keys.any? {|k| k.kind_of? String}, "A key was converted to a string!")
  end

  def test_reverse_merge
    assert_equal({ :a => 1, :b => 2, :c => 10 }, { :a => 1, :b => 2 }.reverse_merge({:a => "x", :b => "y", :c => 10}) )
  end
end

require 'test/unit'
require File.dirname(__FILE__) + '/../../lib/active_support'

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

  def test_indifferent_update
    hash = HashWithIndifferentAccess.new
    hash[:a] = 'a'
    hash['b'] = 'b'
    
    updated_with_strings = hash.update(@strings)
    updated_with_symbols = hash.update(@symbols)
    updated_with_mixed = hash.update(@mixed)

    assert_equal updated_with_strings[:a], 1
    assert_equal updated_with_strings['a'], 1
    assert_equal updated_with_strings['b'], 2

    assert_equal updated_with_symbols[:a], 1
    assert_equal updated_with_symbols['b'], 2
    assert_equal updated_with_symbols[:b], 2

    assert_equal updated_with_mixed[:a], 1
    assert_equal updated_with_mixed['b'], 2

    assert [updated_with_strings, updated_with_symbols, updated_with_mixed].all? {|hash| hash.keys.size == 2}
  end

  def test_indifferent_merging
    hash = HashWithIndifferentAccess.new
    hash[:a] = 'failure'
    hash['b'] = 'failure'
   
    other = { 'a' => 1, :b => 2 }
  
    merged = hash.merge(other)
  
    assert_equal HashWithIndifferentAccess, merged.class
    assert_equal 1, merged[:a]
    assert_equal 2, merged['b']
  
    hash.update(other)
  
    assert_equal 1, hash[:a]
    assert_equal 2, hash['b']
  end
  
  def test_indifferent_deleting
    get_hash = proc{ { :a => 'foo' }.with_indifferent_access }
    hash = get_hash.call
    assert_equal hash.delete(:a), 'foo'
    assert_equal hash.delete(:a), nil
    hash = get_hash.call
    assert_equal hash.delete('a'), 'foo'
    assert_equal hash.delete('a'), nil
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

  def test_diff
    assert_equal({ :a => 2 }, { :a => 2, :b => 5 }.diff({ :a => 1, :b => 5 }))
  end
end

class HashToXmlTest < Test::Unit::TestCase
  def setup
    @xml_options = { :root => :person, :skip_instruct => true, :indent => 0 }
  end

  def test_one_level
    xml = { :name => "David", :street => "Paulina" }.to_xml(@xml_options)
    assert_equal "<person>", xml.first(8)
    assert xml.include?(%(<street>Paulina</street>))
    assert xml.include?(%(<name>David</name>))
  end

  def test_one_level_with_types
    xml = { :name => "David", :street => "Paulina", :age => 26, :moved_on => Date.new(2005, 11, 15) }.to_xml(@xml_options)
    assert_equal "<person>", xml.first(8)
    assert xml.include?(%(<street>Paulina</street>))
    assert xml.include?(%(<name>David</name>))
    assert xml.include?(%(<age type="integer">26</age>))
    assert xml.include?(%(<moved-on type="date">2005-11-15</moved-on>))
  end

  def test_one_level_with_nils
    xml = { :name => "David", :street => "Paulina", :age => nil }.to_xml(@xml_options)
    assert_equal "<person>", xml.first(8)
    assert xml.include?(%(<street>Paulina</street>))
    assert xml.include?(%(<name>David</name>))
    assert xml.include?(%(<age></age>))
  end

  def test_one_level_with_skipping_types
    xml = { :name => "David", :street => "Paulina", :age => nil }.to_xml(@xml_options.merge(:skip_types => true))
    assert_equal "<person>", xml.first(8)
    assert xml.include?(%(<street>Paulina</street>))
    assert xml.include?(%(<name>David</name>))
    assert xml.include?(%(<age></age>))
  end

  def test_two_levels
    xml = { :name => "David", :address => { :street => "Paulina" } }.to_xml(@xml_options)
    assert_equal "<person>", xml.first(8)
    assert xml.include?(%(<address><street>Paulina</street></address>))
    assert xml.include?(%(<name>David</name>))
  end
  
  def test_two_levels_with_array
    xml = { :name => "David", :addresses => [{ :street => "Paulina" }, { :street => "Evergreen" }] }.to_xml(@xml_options)
    assert_equal "<person>", xml.first(8)
    assert xml.include?(%(<addresses><address>))
    assert xml.include?(%(<address><street>Paulina</street></address>))
    assert xml.include?(%(<address><street>Evergreen</street></address>))
    assert xml.include?(%(<name>David</name>))
  end

  
  def test_three_levels_with_array
    xml = { :name => "David", :addresses => [{ :streets => [ { :name => "Paulina" }, { :name => "Paulina" } ] } ] }.to_xml(@xml_options)
    assert xml.include?(%(<addresses><address><streets><street><name>))
  end
end

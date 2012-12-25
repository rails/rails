require 'abstract_unit'
require 'active_support/core_ext/array'
require 'active_support/core_ext/big_decimal'
require 'active_support/core_ext/object/conversions'

require 'active_support/core_ext' # FIXME: pulling in all to_xml extensions
require 'active_support/hash_with_indifferent_access'

class ArrayExtAccessTests < ActiveSupport::TestCase
  def test_from
    assert_equal %w( a b c d ), %w( a b c d ).from(0)
    assert_equal %w( c d ), %w( a b c d ).from(2)
    assert_equal %w(), %w( a b c d ).from(10)
  end

  def test_to
    assert_equal %w( a ), %w( a b c d ).to(0)
    assert_equal %w( a b c ), %w( a b c d ).to(2)
    assert_equal %w( a b c d ), %w( a b c d ).to(10)
  end

  def test_second_through_tenth
    array = (1..42).to_a

    assert_equal array[1], array.second
    assert_equal array[2], array.third
    assert_equal array[3], array.fourth
    assert_equal array[4], array.fifth
    assert_equal array[41], array.forty_two
  end
end

class ArrayExtToParamTests < ActiveSupport::TestCase
  class ToParam < String
    def to_param
      "#{self}1"
    end
  end

  def test_string_array
    assert_equal '', %w().to_param
    assert_equal 'hello/world', %w(hello world).to_param
    assert_equal 'hello/10', %w(hello 10).to_param
  end

  def test_number_array
    assert_equal '10/20', [10, 20].to_param
  end

  def test_to_param_array
    assert_equal 'custom1/param1', [ToParam.new('custom'), ToParam.new('param')].to_param
  end
end

class ArrayExtToSentenceTests < ActiveSupport::TestCase
  def test_plain_array_to_sentence
    assert_equal "", [].to_sentence
    assert_equal "one", ['one'].to_sentence
    assert_equal "one and two", ['one', 'two'].to_sentence
    assert_equal "one, two, and three", ['one', 'two', 'three'].to_sentence
  end

  def test_to_sentence_with_words_connector
    assert_equal "one two, and three", ['one', 'two', 'three'].to_sentence(:words_connector => ' ')
    assert_equal "one & two, and three", ['one', 'two', 'three'].to_sentence(:words_connector => ' & ')
    assert_equal "onetwo, and three", ['one', 'two', 'three'].to_sentence(:words_connector => nil)
  end

  def test_to_sentence_with_last_word_connector
    assert_equal "one, two, and also three", ['one', 'two', 'three'].to_sentence(:last_word_connector => ', and also ')
    assert_equal "one, twothree", ['one', 'two', 'three'].to_sentence(:last_word_connector => nil)
    assert_equal "one, two three", ['one', 'two', 'three'].to_sentence(:last_word_connector => ' ')
    assert_equal "one, two and three", ['one', 'two', 'three'].to_sentence(:last_word_connector => ' and ')
  end

  def test_two_elements
    assert_equal "one and two", ['one', 'two'].to_sentence
    assert_equal "one two", ['one', 'two'].to_sentence(:two_words_connector => ' ')
  end

  def test_one_element
    assert_equal "one", ['one'].to_sentence
  end

  def test_one_element_not_same_object
    elements = ["one"]
    assert_not_equal elements[0].object_id, elements.to_sentence.object_id
  end

  def test_one_non_string_element
    assert_equal '1', [1].to_sentence
  end

  def test_does_not_modify_given_hash
    options = { words_connector: ' ' }
    assert_equal "one two, and three", ['one', 'two', 'three'].to_sentence(options)
    assert_equal({ words_connector: ' ' }, options)
  end
end

class ArrayExtToSTests < ActiveSupport::TestCase
  def test_to_s_db
    collection = [
      Class.new { def id() 1 end }.new,
      Class.new { def id() 2 end }.new,
      Class.new { def id() 3 end }.new
    ]

    assert_equal "null", [].to_s(:db)
    assert_equal "1,2,3", collection.to_s(:db)
  end
end

class ArrayExtGroupingTests < ActiveSupport::TestCase
  def setup
    Fixnum.send :private, :/  # test we avoid Integer#/ (redefined by mathn)
  end

  def teardown
    Fixnum.send :public, :/
  end

  def test_in_groups_of_with_perfect_fit
    groups = []
    ('a'..'i').to_a.in_groups_of(3) do |group|
      groups << group
    end

    assert_equal [%w(a b c), %w(d e f), %w(g h i)], groups
    assert_equal [%w(a b c), %w(d e f), %w(g h i)], ('a'..'i').to_a.in_groups_of(3)
  end

  def test_in_groups_of_with_padding
    groups = []
    ('a'..'g').to_a.in_groups_of(3) do |group|
      groups << group
    end

    assert_equal [%w(a b c), %w(d e f), ['g', nil, nil]], groups
  end

  def test_in_groups_of_pads_with_specified_values
    groups = []

    ('a'..'g').to_a.in_groups_of(3, 'foo') do |group|
      groups << group
    end

    assert_equal [%w(a b c), %w(d e f), ['g', 'foo', 'foo']], groups
  end

  def test_in_groups_of_without_padding
    groups = []

    ('a'..'g').to_a.in_groups_of(3, false) do |group|
      groups << group
    end

    assert_equal [%w(a b c), %w(d e f), ['g']], groups
  end

  def test_in_groups_returned_array_size
    array = (1..7).to_a

    1.upto(array.size + 1) do |number|
      assert_equal number, array.in_groups(number).size
    end
  end

  def test_in_groups_with_empty_array
    assert_equal [[], [], []], [].in_groups(3)
  end

  def test_in_groups_with_block
    array = (1..9).to_a
    groups = []

    array.in_groups(3) do |group|
      groups << group
    end

    assert_equal array.in_groups(3), groups
  end

  def test_in_groups_with_perfect_fit
    assert_equal [[1, 2, 3], [4, 5, 6], [7, 8, 9]],
      (1..9).to_a.in_groups(3)
  end

  def test_in_groups_with_padding
    array = (1..7).to_a

    assert_equal [[1, 2, 3], [4, 5, nil], [6, 7, nil]],
      array.in_groups(3)
    assert_equal [[1, 2, 3], [4, 5, 'foo'], [6, 7, 'foo']],
      array.in_groups(3, 'foo')
  end

  def test_in_groups_without_padding
    assert_equal [[1, 2, 3], [4, 5], [6, 7]],
      (1..7).to_a.in_groups(3, false)
  end
end

class ArraySplitTests < ActiveSupport::TestCase
  def test_split_with_empty_array
    assert_equal [[]], [].split(0)
  end

  def test_split_with_argument
    assert_equal [[1, 2], [4, 5]],  [1, 2, 3, 4, 5].split(3)
    assert_equal [[1, 2, 3, 4, 5]], [1, 2, 3, 4, 5].split(0)
  end

  def test_split_with_block
    assert_equal [[1, 2], [4, 5], [7, 8], [10]], (1..10).to_a.split { |i| i % 3 == 0 }
  end

  def test_split_with_edge_values
    assert_equal [[], [2, 3, 4, 5]],  [1, 2, 3, 4, 5].split(1)
    assert_equal [[1, 2, 3, 4], []],  [1, 2, 3, 4, 5].split(5)
    assert_equal [[], [2, 3, 4], []], [1, 2, 3, 4, 5].split { |i| i == 1 || i == 5 }
  end
end

class ArrayToXmlTests < ActiveSupport::TestCase
  def test_to_xml
    xml = [
      { :name => "David", :age => 26, :age_in_millis => 820497600000 },
      { :name => "Jason", :age => 31, :age_in_millis => BigDecimal.new('1.0') }
    ].to_xml(:skip_instruct => true, :indent => 0)

    assert_equal '<objects type="array"><object>', xml.first(30)
    assert xml.include?(%(<age type="integer">26</age>)), xml
    assert xml.include?(%(<age-in-millis type="integer">820497600000</age-in-millis>)), xml
    assert xml.include?(%(<name>David</name>)), xml
    assert xml.include?(%(<age type="integer">31</age>)), xml
    assert xml.include?(%(<age-in-millis type="decimal">1.0</age-in-millis>)), xml
    assert xml.include?(%(<name>Jason</name>)), xml
  end

  def test_to_xml_with_dedicated_name
    xml = [
      { :name => "David", :age => 26, :age_in_millis => 820497600000 }, { :name => "Jason", :age => 31 }
    ].to_xml(:skip_instruct => true, :indent => 0, :root => "people")

    assert_equal '<people type="array"><person>', xml.first(29)
  end

  def test_to_xml_with_options
    xml = [
      { :name => "David", :street_address => "Paulina" }, { :name => "Jason", :street_address => "Evergreen" }
    ].to_xml(:skip_instruct => true, :skip_types => true, :indent => 0)

    assert_equal "<objects><object>", xml.first(17)
    assert xml.include?(%(<street-address>Paulina</street-address>))
    assert xml.include?(%(<name>David</name>))
    assert xml.include?(%(<street-address>Evergreen</street-address>))
    assert xml.include?(%(<name>Jason</name>))
  end

  def test_to_xml_with_dasherize_false
    xml = [
      { :name => "David", :street_address => "Paulina" }, { :name => "Jason", :street_address => "Evergreen" }
    ].to_xml(:skip_instruct => true, :skip_types => true, :indent => 0, :dasherize => false)

    assert_equal "<objects><object>", xml.first(17)
    assert xml.include?(%(<street_address>Paulina</street_address>))
    assert xml.include?(%(<street_address>Evergreen</street_address>))
  end

  def test_to_xml_with_dasherize_true
    xml = [
      { :name => "David", :street_address => "Paulina" }, { :name => "Jason", :street_address => "Evergreen" }
    ].to_xml(:skip_instruct => true, :skip_types => true, :indent => 0, :dasherize => true)

    assert_equal "<objects><object>", xml.first(17)
    assert xml.include?(%(<street-address>Paulina</street-address>))
    assert xml.include?(%(<street-address>Evergreen</street-address>))
  end

  def test_to_with_instruct
    xml = [
      { :name => "David", :age => 26, :age_in_millis => 820497600000 },
      { :name => "Jason", :age => 31, :age_in_millis => BigDecimal.new('1.0') }
    ].to_xml(:skip_instruct => false, :indent => 0)

    assert_match(/^<\?xml [^>]*/, xml)
    assert_equal 0, xml.rindex(/<\?xml /)
  end

  def test_to_xml_with_block
    xml = [
      { :name => "David", :age => 26, :age_in_millis => 820497600000 },
      { :name => "Jason", :age => 31, :age_in_millis => BigDecimal.new('1.0') }
    ].to_xml(:skip_instruct => true, :indent => 0) do |builder|
      builder.count 2
    end

    assert xml.include?(%(<count>2</count>)), xml
  end

  def test_to_xml_with_empty
    xml = [].to_xml
    assert_match(/type="array"\/>/, xml)
  end

  def test_to_xml_dups_options
    options = {:skip_instruct => true}
    [].to_xml(options)
    # :builder, etc, shouldn't be added to options
    assert_equal({:skip_instruct => true}, options)
  end
end

class ArrayExtractOptionsTests < ActiveSupport::TestCase
  class HashSubclass < Hash
  end

  class ExtractableHashSubclass < Hash
    def extractable_options?
      true
    end
  end

  def test_extract_options
    assert_equal({}, [].extract_options!)
    assert_equal({}, [1].extract_options!)
    assert_equal({:a=>:b}, [{:a=>:b}].extract_options!)
    assert_equal({:a=>:b}, [1, {:a=>:b}].extract_options!)
  end

  def test_extract_options_doesnt_extract_hash_subclasses
    hash = HashSubclass.new
    hash[:foo] = 1
    array = [hash]
    options = array.extract_options!
    assert_equal({}, options)
    assert_equal [hash], array
  end

  def test_extract_options_extracts_extractable_subclass
    hash = ExtractableHashSubclass.new
    hash[:foo] = 1
    array = [hash]
    options = array.extract_options!
    assert_equal({:foo => 1}, options)
    assert_equal [], array
  end

  def test_extract_options_extracts_hwia
    hash = [{:foo => 1}.with_indifferent_access]
    options = hash.extract_options!
    assert_equal 1, options[:foo]
  end
end

class ArrayUniqByTests < ActiveSupport::TestCase
  def test_uniq_by
    ActiveSupport::Deprecation.silence do
      assert_equal [1,2], [1,2,3,4].uniq_by { |i| i.odd? }
      assert_equal [1,2], [1,2,3,4].uniq_by(&:even?)
      assert_equal((-5..0).to_a, (-5..5).to_a.uniq_by{ |i| i**2 })
    end
  end

  def test_uniq_by!
    a = [1,2,3,4]
    ActiveSupport::Deprecation.silence do
      a.uniq_by! { |i| i.odd? }
    end
    assert_equal [1,2], a

    a = [1,2,3,4]
    ActiveSupport::Deprecation.silence do
      a.uniq_by! { |i| i.even? }
    end
    assert_equal [1,2], a

    a = (-5..5).to_a
    ActiveSupport::Deprecation.silence do
      a.uniq_by! { |i| i**2 }
    end
    assert_equal((-5..0).to_a, a)
  end
end

class ArrayWrapperTests < ActiveSupport::TestCase
  class FakeCollection
    def to_ary
      ["foo", "bar"]
    end
  end

  class Proxy
    def initialize(target) @target = target end
    def method_missing(*a) @target.send(*a) end
  end

  class DoubtfulToAry
    def to_ary
      :not_an_array
    end
  end

  class NilToAry
    def to_ary
      nil
    end
  end

  def test_array
    ary = %w(foo bar)
    assert_same ary, Array.wrap(ary)
  end

  def test_nil
    assert_equal [], Array.wrap(nil)
  end

  def test_object
    o = Object.new
    assert_equal [o], Array.wrap(o)
  end

  def test_string
    assert_equal ["foo"], Array.wrap("foo")
  end

  def test_string_with_newline
    assert_equal ["foo\nbar"], Array.wrap("foo\nbar")
  end

  def test_object_with_to_ary
    assert_equal ["foo", "bar"], Array.wrap(FakeCollection.new)
  end

  def test_proxy_object
    p = Proxy.new(Object.new)
    assert_equal [p], Array.wrap(p)
  end

  def test_proxy_to_object_with_to_ary
    p = Proxy.new(FakeCollection.new)
    assert_equal [p], Array.wrap(p)
  end

  def test_struct
    o = Struct.new(:foo).new(123)
    assert_equal [o], Array.wrap(o)
  end

  def test_wrap_returns_wrapped_if_to_ary_returns_nil
    o = NilToAry.new
    assert_equal [o], Array.wrap(o)
  end

  def test_wrap_does_not_complain_if_to_ary_does_not_return_an_array
    assert_equal DoubtfulToAry.new.to_ary, Array.wrap(DoubtfulToAry.new)
  end
end

class ArrayPrependAppendTest < ActiveSupport::TestCase
  def test_append
    assert_equal [1, 2], [1].append(2)
  end

  def test_prepend
    assert_equal [2, 1], [1].prepend(2)
  end
end

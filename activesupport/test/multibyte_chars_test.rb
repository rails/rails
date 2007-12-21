require 'abstract_unit'

if RUBY_VERSION >= '1.9'
  class CharsTest < Test::Unit::TestCase
    def test_chars_returns_self
      str = 'abc'
      assert_equal str.object_id, str.chars.object_id
    end
  end
else

$KCODE = 'UTF8'

class CharsTest < Test::Unit::TestCase
  
  def setup
    @s = {
      :utf8 => "Abcd Блå ﬃ блa  埋",
      :ascii => "asci ias c iia s",
      :bytes => "\270\236\010\210\245"
    }
  end
  
  def test_sanity
    @s.each do |t, s|
      assert s.respond_to?(:chars), "All string should have the chars method (#{t})"
      assert s.respond_to?(:to_s), "All string should have the to_s method (#{t})"
      assert_kind_of ActiveSupport::Multibyte::Chars, s.chars, "#chars should return an instance of Chars (#{t})"
    end
  end
  
  def test_comparability
    @s.each do |t, s|
      assert_equal s, s.chars.to_s, "Chars#to_s should return enclosed string unchanged"
    end
    assert_nothing_raised do
      assert_equal "a", "a", "Normal string comparisons should be unaffected"
      assert_not_equal "a", "b", "Normal string comparisons should be unaffected"
      assert_not_equal "a".chars, "b".chars, "Chars objects should be comparable"
      assert_equal "a".chars, "A".downcase.chars, "Chars objects should be comparable to each other"
      assert_equal "a".chars, "A".downcase, "Chars objects should be comparable to strings coming from elsewhere"
    end
    
    assert !@s[:utf8].eql?(@s[:utf8].chars), "Strict comparison is not supported"
    assert_equal @s[:utf8], @s[:utf8].chars, "Chars should be compared by their enclosed string"

    other_string = @s[:utf8].dup
    assert_equal other_string, @s[:utf8].chars, "Chars should be compared by their enclosed string"
    assert_equal other_string.chars, @s[:utf8].chars, "Chars should be compared by their enclosed string"
    
    strings = ['builder'.chars, 'armor'.chars, 'zebra'.chars]
    strings.sort!
    assert_equal ['armor', 'builder', 'zebra'], strings, "Chars should be sortable based on their enclosed string"

    # This leads to a StackLevelTooDeep exception if the comparison is not wired properly
    assert_raise(NameError) do
      Chars
    end
  end
  
  def test_utf8?
    assert @s[:utf8].is_utf8?, "UTF-8 strings are UTF-8"
    assert @s[:ascii].is_utf8?, "All ASCII strings are also valid UTF-8"
    assert !@s[:bytes].is_utf8?, "This bytestring isn't UTF-8"
  end
  
  # The test for the following methods are defined here because they can only be defined on the Chars class for
  # various reasons 
  
  def test_gsub
    assert_equal 'éxa', 'éda'.chars.gsub(/d/, 'x')
    with_kcode('none') do
      assert_equal 'éxa', 'éda'.chars.gsub(/d/, 'x')
    end
  end
  
  def test_split
    word = "eﬃcient"
    chars = ["e", "ﬃ", "c", "i", "e", "n", "t"]
    assert_equal chars, word.split(//)
    assert_equal chars, word.chars.split(//)
    assert_kind_of ActiveSupport::Multibyte::Chars, word.chars.split(//).first, "Split should return Chars instances"
  end
  
  def test_regexp
    with_kcode('none') do
      assert_equal 12, (@s[:utf8].chars =~ /ﬃ/),
        "Regex matching should be bypassed to String"
    end
    with_kcode('UTF8') do
      assert_equal 9, (@s[:utf8].chars =~ /ﬃ/),
        "Regex matching should be unicode aware"
      assert_nil((''.chars =~ /\d+/),
        "Non-matching regular expressions should return nil")
    end
  end

  def test_pragma
    if RUBY_VERSION < '1.9'
      with_kcode('UTF8') do
        assert " ".chars.send(:utf8_pragma?), "UTF8 pragma should be on because KCODE is UTF8"
      end
      with_kcode('none') do
        assert !" ".chars.send(:utf8_pragma?), "UTF8 pragma should be off because KCODE is not UTF8"
      end
    else
      assert !" ".chars.send(:utf8_pragma?), "UTF8 pragma should be off in Ruby 1.9"
    end
  end

  def test_handler_setting
    handler = ''.chars.handler
    
    ActiveSupport::Multibyte::Chars.handler = :first
    assert_equal :first, ''.chars.handler
    ActiveSupport::Multibyte::Chars.handler = :second
    assert_equal :second, ''.chars.handler
    assert_raise(NoMethodError) do
      ''.chars.handler.split
    end
    
    ActiveSupport::Multibyte::Chars.handler = handler
  end
  
  def test_method_chaining
    assert_kind_of ActiveSupport::Multibyte::Chars, ''.chars.downcase
    assert_kind_of ActiveSupport::Multibyte::Chars, ''.chars.strip, "Strip should return a Chars object"
    assert_kind_of ActiveSupport::Multibyte::Chars, ''.chars.downcase.strip, "The Chars object should be " +
        "forwarded down the call path for chaining"
    assert_equal 'foo', "  FOO   ".chars.normalize.downcase.strip, "The Chars that results from the " +
      " operations should be comparable to the string value of the result"
  end
  
  def test_passthrough_on_kcode
    # The easiest way to check if the passthrough is in place is through #size
    with_kcode('none') do
      assert_equal 26, @s[:utf8].chars.size
    end
    with_kcode('UTF8') do
      assert_equal 17, @s[:utf8].chars.size
    end
  end
    
  def test_destructiveness  
    # Note that we're testing the destructiveness here and not the correct behaviour of the methods
    str = 'ac'
    str.chars.insert(1, 'b')
    assert_equal 'abc', str, 'Insert should be destructive for a string'
    
    str = 'ac'
    str.chars.reverse!
    assert_equal 'ca', str, 'reverse! should be destructive for a string'
  end
  
  def test_resilience
    assert_nothing_raised do
      assert_equal 5, @s[:bytes].chars.size, "The sequence contains five interpretable bytes"
    end
    reversed = [0xb8, 0x17e, 0x8, 0x2c6, 0xa5].reverse.pack('U*')
    assert_nothing_raised do
      assert_equal reversed, @s[:bytes].chars.reverse.to_s, "Reversing the string should only yield interpretable bytes"
    end
    assert_nothing_raised do
      @s[:bytes].chars.reverse!
      assert_equal reversed, @s[:bytes].to_s, "Reversing the string should only yield interpretable bytes"
    end
  end
  
  def test_duck_typing
    assert_equal true,  'test'.chars.respond_to?(:strip)
    assert_equal true,  'test'.chars.respond_to?(:normalize)
    assert_equal true,  'test'.chars.respond_to?(:normalize!)
    assert_equal false, 'test'.chars.respond_to?(:a_method_that_doesnt_exist)
  end
  
  protected

  def with_kcode(kcode)
    old_kcode, $KCODE = $KCODE, kcode
    begin
      yield
    ensure
      $KCODE = old_kcode
    end
  end
end

end

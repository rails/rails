# encoding: utf-8

require 'abstract_unit'
require 'multibyte_test_helpers'

class String
  def __method_for_multibyte_testing_with_integer_result; 1; end
  def __method_for_multibyte_testing; 'result'; end
  def __method_for_multibyte_testing!; 'result'; end
end

class MultibyteCharsTest < Test::Unit::TestCase
  include MultibyteTestHelpers

  def setup
    @proxy_class = ActiveSupport::Multibyte::Chars
    @chars = @proxy_class.new UNICODE_STRING
  end

  def test_wraps_the_original_string
    assert_equal UNICODE_STRING, @chars.to_s
    assert_equal UNICODE_STRING, @chars.wrapped_string
  end

  def test_should_allow_method_calls_to_string
    assert_nothing_raised do
      @chars.__method_for_multibyte_testing
    end
    assert_raises NoMethodError do
      @chars.__unknown_method
    end
  end

  def test_forwarded_method_calls_should_return_new_chars_instance
    assert @chars.__method_for_multibyte_testing.kind_of?(@proxy_class)
    assert_not_equal @chars.object_id, @chars.__method_for_multibyte_testing.object_id
  end

  def test_forwarded_bang_method_calls_should_return_the_original_chars_instance
    assert @chars.__method_for_multibyte_testing!.kind_of?(@proxy_class)
    assert_equal @chars.object_id, @chars.__method_for_multibyte_testing!.object_id
  end

  def test_methods_are_forwarded_to_wrapped_string_for_byte_strings
    assert_equal BYTE_STRING.class, BYTE_STRING.mb_chars.class
  end

  def test_forwarded_method_with_non_string_result_should_be_returned_vertabim
    assert_equal ''.__method_for_multibyte_testing_with_integer_result, @chars.__method_for_multibyte_testing_with_integer_result
  end

  def test_should_concatenate
    assert_equal 'ab', 'a'.mb_chars + 'b'
    assert_equal 'ab', 'a' + 'b'.mb_chars
    assert_equal 'ab', 'a'.mb_chars + 'b'.mb_chars

    assert_equal 'ab', 'a'.mb_chars << 'b'
    assert_equal 'ab', 'a' << 'b'.mb_chars
    assert_equal 'ab', 'a'.mb_chars << 'b'.mb_chars
  end

  def test_consumes_utf8_strings
    assert @proxy_class.consumes?(UNICODE_STRING)
    assert @proxy_class.consumes?(ASCII_STRING)
    assert !@proxy_class.consumes?(BYTE_STRING)
  end

  def test_unpack_utf8_strings
    assert_equal 4, @proxy_class.u_unpack(UNICODE_STRING).length
    assert_equal 5, @proxy_class.u_unpack(ASCII_STRING).length
  end

  def test_unpack_raises_encoding_error_on_broken_strings
    assert_raises(ActiveSupport::Multibyte::EncodingError) do
      @proxy_class.u_unpack(BYTE_STRING)
    end
  end

  if RUBY_VERSION < '1.9'
    def test_concatenation_should_return_a_proxy_class_instance
      assert_equal ActiveSupport::Multibyte.proxy_class, ('a'.mb_chars + 'b').class
      assert_equal ActiveSupport::Multibyte.proxy_class, ('a'.mb_chars << 'b').class
    end

    def test_ascii_strings_are_treated_at_utf8_strings
      assert_equal ActiveSupport::Multibyte.proxy_class, ASCII_STRING.mb_chars.class
    end

    def test_concatenate_should_return_proxy_instance
      assert(('a'.mb_chars + 'b').kind_of?(@proxy_class))
      assert(('a'.mb_chars + 'b'.mb_chars).kind_of?(@proxy_class))
      assert(('a'.mb_chars << 'b').kind_of?(@proxy_class))
      assert(('a'.mb_chars << 'b'.mb_chars).kind_of?(@proxy_class))
    end
  end
end

class MultibyteCharsUTF8BehaviourTest < Test::Unit::TestCase
  include MultibyteTestHelpers

  def setup
    @chars = UNICODE_STRING.dup.mb_chars

    # NEWLINE, SPACE, EM SPACE
    @whitespace = "\n#{[32, 8195].pack('U*')}"
    @whitespace.force_encoding(Encoding::UTF_8) if @whitespace.respond_to?(:force_encoding)
    @byte_order_mark = [65279].pack('U')
  end

  if RUBY_VERSION < '1.9'
    def test_split_should_return_an_array_of_chars_instances
      @chars.split(//).each do |character|
        assert character.kind_of?(ActiveSupport::Multibyte.proxy_class)
      end
    end

    def test_indexed_insert_accepts_fixnums
      @chars[2] = 32
      assert_equal 'こに わ', @chars
    end

    def test_overridden_bang_methods_return_self
      [:rstrip!, :lstrip!, :strip!, :reverse!, :upcase!, :downcase!, :capitalize!].each do |method|
        assert_equal @chars.object_id, @chars.send(method).object_id
      end
      assert_equal @chars.object_id, @chars.slice!(1).object_id
    end

    def test_overridden_bang_methods_change_wrapped_string
      [:rstrip!, :lstrip!, :strip!, :reverse!, :upcase!, :downcase!].each do |method|
        original = ' Café '
        proxy = chars(original.dup)
        proxy.send(method)
        assert_not_equal original, proxy.to_s
      end
      proxy = chars('Café')
      proxy.slice!(3)
      assert_equal 'é', proxy.to_s

      proxy = chars('òu')
      proxy.capitalize!
      assert_equal 'Òu', proxy.to_s
    end
  end

  if RUBY_VERSION >= '1.9'
    def test_unicode_string_should_have_utf8_encoding
      assert_equal Encoding::UTF_8, UNICODE_STRING.encoding
    end
  end

  def test_identity
    assert_equal @chars, @chars
    assert @chars.eql?(@chars)
    if RUBY_VERSION <= '1.9'
      assert !@chars.eql?(UNICODE_STRING)
    else
      assert @chars.eql?(UNICODE_STRING)
    end
  end

  def test_string_methods_are_chainable
    assert chars('').insert(0, '').kind_of?(ActiveSupport::Multibyte.proxy_class)
    assert chars('').rjust(1).kind_of?(ActiveSupport::Multibyte.proxy_class)
    assert chars('').ljust(1).kind_of?(ActiveSupport::Multibyte.proxy_class)
    assert chars('').center(1).kind_of?(ActiveSupport::Multibyte.proxy_class)
    assert chars('').rstrip.kind_of?(ActiveSupport::Multibyte.proxy_class)
    assert chars('').lstrip.kind_of?(ActiveSupport::Multibyte.proxy_class)
    assert chars('').strip.kind_of?(ActiveSupport::Multibyte.proxy_class)
    assert chars('').reverse.kind_of?(ActiveSupport::Multibyte.proxy_class)
    assert chars(' ').slice(0).kind_of?(ActiveSupport::Multibyte.proxy_class)
    assert chars('').upcase.kind_of?(ActiveSupport::Multibyte.proxy_class)
    assert chars('').downcase.kind_of?(ActiveSupport::Multibyte.proxy_class)
    assert chars('').capitalize.kind_of?(ActiveSupport::Multibyte.proxy_class)
    assert chars('').normalize.kind_of?(ActiveSupport::Multibyte.proxy_class)
    assert chars('').decompose.kind_of?(ActiveSupport::Multibyte.proxy_class)
    assert chars('').compose.kind_of?(ActiveSupport::Multibyte.proxy_class)
    assert chars('').tidy_bytes.kind_of?(ActiveSupport::Multibyte.proxy_class)
  end

  def test_should_be_equal_to_the_wrapped_string
    assert_equal UNICODE_STRING, @chars
    assert_equal @chars, UNICODE_STRING
  end

  def test_should_not_be_equal_to_an_other_string
    assert_not_equal @chars, 'other'
    assert_not_equal 'other', @chars
  end

  def test_sortability
    words = %w(builder armor zebra).map(&:mb_chars).sort
    assert_equal %w(armor builder zebra), words
  end

  def test_should_return_character_offset_for_regexp_matches
    assert_nil(@chars =~ /wrong/u)
    assert_equal 0, (@chars =~ /こ/u)
    assert_equal 1, (@chars =~ /に/u)
    assert_equal 3, (@chars =~ /わ/u)
  end

  def test_should_use_character_offsets_for_insert_offsets
    assert_equal '', ''.mb_chars.insert(0, '')
    assert_equal 'こわにちわ', @chars.insert(1, 'わ')
    assert_equal 'こわわわにちわ', @chars.insert(2, 'わわ')
    assert_equal 'わこわわわにちわ', @chars.insert(0, 'わ')
    assert_equal 'わこわわわにちわ', @chars.wrapped_string if RUBY_VERSION < '1.9'
  end

  def test_insert_should_be_destructive
    @chars.insert(1, 'わ')
    assert_equal 'こわにちわ', @chars
  end

  def test_insert_throws_index_error
    assert_raises(IndexError) { @chars.insert(-12, 'わ')}
    assert_raises(IndexError) { @chars.insert(12, 'わ') }
  end

  def test_should_know_if_one_includes_the_other
    assert @chars.include?('')
    assert @chars.include?('ち')
    assert @chars.include?('わ')
    assert !@chars.include?('こちわ')
    assert !@chars.include?('a')
  end

  def test_include_raises_type_error_when_nil_is_passed
    assert_raises(TypeError) do
      @chars.include?(nil)
    end
  end

  def test_index_should_return_character_offset
    assert_nil @chars.index('u')
    assert_equal 0, @chars.index('こに')
    assert_equal 2, @chars.index('ち')
    assert_equal 3, @chars.index('わ')
  end

  def test_indexed_insert_should_take_character_offsets
    @chars[2] = 'a'
    assert_equal 'こにaわ', @chars
    @chars[2] = 'ηη'
    assert_equal 'こにηηわ', @chars
    @chars[3, 2] = 'λλλ'
    assert_equal 'こにηλλλ', @chars
    @chars[1, 0] = "λ"
    assert_equal 'こλにηλλλ', @chars
    @chars[4..6] = "ηη"
    assert_equal 'こλにηηη', @chars
    @chars[/ηη/] = "λλλ"
    assert_equal 'こλにλλλη', @chars
    @chars[/(λλ)(.)/, 2] = "α"
    assert_equal 'こλにλλαη', @chars
    @chars["α"] = "¢"
    assert_equal 'こλにλλ¢η', @chars
    @chars["λλ"] = "ααα"
    assert_equal 'こλにααα¢η', @chars
  end

  def test_indexed_insert_should_raise_on_index_overflow
    before = @chars.to_s
    assert_raises(IndexError) { @chars[10] = 'a' }
    assert_raises(IndexError) { @chars[10, 4] = 'a' }
    assert_raises(IndexError) { @chars[/ii/] = 'a' }
    assert_raises(IndexError) { @chars[/()/, 10] = 'a' }
    assert_equal before, @chars
  end

  def test_indexed_insert_should_raise_on_range_overflow
    before = @chars.to_s
    assert_raises(RangeError) { @chars[10..12] = 'a' }
    assert_equal before, @chars
  end

  def test_rjust_should_raise_argument_errors_on_bad_arguments
    assert_raises(ArgumentError) { @chars.rjust(10, '') }
    assert_raises(ArgumentError) { @chars.rjust }
  end

  def test_rjust_should_count_characters_instead_of_bytes
    assert_equal UNICODE_STRING, @chars.rjust(-3)
    assert_equal UNICODE_STRING, @chars.rjust(0)
    assert_equal UNICODE_STRING, @chars.rjust(4)
    assert_equal " #{UNICODE_STRING}", @chars.rjust(5)
    assert_equal "   #{UNICODE_STRING}", @chars.rjust(7)
    assert_equal "---#{UNICODE_STRING}", @chars.rjust(7, '-')
    assert_equal "ααα#{UNICODE_STRING}", @chars.rjust(7, 'α')
    assert_equal "aba#{UNICODE_STRING}", @chars.rjust(7, 'ab')
    assert_equal "αηα#{UNICODE_STRING}", @chars.rjust(7, 'αη')
    assert_equal "αηαη#{UNICODE_STRING}", @chars.rjust(8, 'αη')
  end

  def test_ljust_should_raise_argument_errors_on_bad_arguments
    assert_raises(ArgumentError) { @chars.ljust(10, '') }
    assert_raises(ArgumentError) { @chars.ljust }
  end

  def test_ljust_should_count_characters_instead_of_bytes
    assert_equal UNICODE_STRING, @chars.ljust(-3)
    assert_equal UNICODE_STRING, @chars.ljust(0)
    assert_equal UNICODE_STRING, @chars.ljust(4)
    assert_equal "#{UNICODE_STRING} ", @chars.ljust(5)
    assert_equal "#{UNICODE_STRING}   ", @chars.ljust(7)
    assert_equal "#{UNICODE_STRING}---", @chars.ljust(7, '-')
    assert_equal "#{UNICODE_STRING}ααα", @chars.ljust(7, 'α')
    assert_equal "#{UNICODE_STRING}aba", @chars.ljust(7, 'ab')
    assert_equal "#{UNICODE_STRING}αηα", @chars.ljust(7, 'αη')
    assert_equal "#{UNICODE_STRING}αηαη", @chars.ljust(8, 'αη')
  end

  def test_center_should_raise_argument_errors_on_bad_arguments
    assert_raises(ArgumentError) { @chars.center(10, '') }
    assert_raises(ArgumentError) { @chars.center }
  end

  def test_center_should_count_charactes_instead_of_bytes
    assert_equal UNICODE_STRING, @chars.center(-3)
    assert_equal UNICODE_STRING, @chars.center(0)
    assert_equal UNICODE_STRING, @chars.center(4)
    assert_equal "#{UNICODE_STRING} ", @chars.center(5)
    assert_equal " #{UNICODE_STRING} ", @chars.center(6)
    assert_equal " #{UNICODE_STRING}  ", @chars.center(7)
    assert_equal "--#{UNICODE_STRING}--", @chars.center(8, '-')
    assert_equal "--#{UNICODE_STRING}---", @chars.center(9, '-')
    assert_equal "αα#{UNICODE_STRING}αα", @chars.center(8, 'α')
    assert_equal "αα#{UNICODE_STRING}ααα", @chars.center(9, 'α')
    assert_equal "a#{UNICODE_STRING}ab", @chars.center(7, 'ab')
    assert_equal "ab#{UNICODE_STRING}ab", @chars.center(8, 'ab')
    assert_equal "abab#{UNICODE_STRING}abab", @chars.center(12, 'ab')
    assert_equal "α#{UNICODE_STRING}αη", @chars.center(7, 'αη')
    assert_equal "αη#{UNICODE_STRING}αη", @chars.center(8, 'αη')
  end

  def test_lstrip_strips_whitespace_from_the_left_of_the_string
    assert_equal UNICODE_STRING, UNICODE_STRING.mb_chars.lstrip
    assert_equal UNICODE_STRING, (@whitespace + UNICODE_STRING).mb_chars.lstrip
    assert_equal UNICODE_STRING + @whitespace, (@whitespace + UNICODE_STRING + @whitespace).mb_chars.lstrip
  end

  def test_rstrip_strips_whitespace_from_the_right_of_the_string
    assert_equal UNICODE_STRING, UNICODE_STRING.mb_chars.rstrip
    assert_equal UNICODE_STRING, (UNICODE_STRING + @whitespace).mb_chars.rstrip
    assert_equal @whitespace + UNICODE_STRING, (@whitespace + UNICODE_STRING + @whitespace).mb_chars.rstrip
  end

  def test_strip_strips_whitespace
    assert_equal UNICODE_STRING, UNICODE_STRING.mb_chars.strip
    assert_equal UNICODE_STRING, (@whitespace + UNICODE_STRING).mb_chars.strip
    assert_equal UNICODE_STRING, (UNICODE_STRING + @whitespace).mb_chars.strip
    assert_equal UNICODE_STRING, (@whitespace + UNICODE_STRING + @whitespace).mb_chars.strip
  end

  def test_stripping_whitespace_leaves_whitespace_within_the_string_intact
    string_with_whitespace = UNICODE_STRING + @whitespace + UNICODE_STRING
    assert_equal string_with_whitespace, string_with_whitespace.mb_chars.strip
    assert_equal string_with_whitespace, string_with_whitespace.mb_chars.lstrip
    assert_equal string_with_whitespace, string_with_whitespace.mb_chars.rstrip
  end

  def test_size_returns_characters_instead_of_bytes
    assert_equal 0, ''.mb_chars.size
    assert_equal 4, @chars.size
    assert_equal 4, @chars.length
    assert_equal 5, ASCII_STRING.mb_chars.size
  end

  def test_reverse_reverses_characters
    assert_equal '', ''.mb_chars.reverse
    assert_equal 'わちにこ', @chars.reverse
  end

  def test_slice_should_take_character_offsets
    assert_equal nil, ''.mb_chars.slice(0)
    assert_equal 'こ', @chars.slice(0)
    assert_equal 'わ', @chars.slice(3)
    assert_equal nil, ''.mb_chars.slice(-1..1)
    assert_equal '', ''.mb_chars.slice(0..10)
    assert_equal 'にちわ', @chars.slice(1..3)
    assert_equal 'にちわ', @chars.slice(1, 3)
    assert_equal 'こ', @chars.slice(0, 1)
    assert_equal 'ちわ', @chars.slice(2..10)
    assert_equal '', @chars.slice(4..10)
    assert_equal 'に', @chars.slice(/に/u)
    assert_equal 'にち', @chars.slice(/に\w/u)
    assert_equal nil, @chars.slice(/unknown/u)
    assert_equal 'にち', @chars.slice(/(にち)/u, 1)
    assert_equal nil, @chars.slice(/(にち)/u, 2)
    assert_equal nil, @chars.slice(7..6)
  end

  def test_slice_should_throw_exceptions_on_invalid_arguments
    assert_raise(TypeError) { @chars.slice(2..3, 1) }
    assert_raise(TypeError) { @chars.slice(1, 2..3) }
    assert_raise(ArgumentError) { @chars.slice(1, 1, 1) }
  end

  def test_ord_should_return_unicode_value_for_first_character
    assert_equal 12371, @chars.ord
  end

  def test_upcase_should_upcase_ascii_characters
    assert_equal '', ''.mb_chars.upcase
    assert_equal 'ABC', 'aBc'.mb_chars.upcase
  end

  def test_downcase_should_downcase_ascii_characters
    assert_equal '', ''.mb_chars.downcase
    assert_equal 'abc', 'aBc'.mb_chars.downcase
  end

  def test_capitalize_should_work_on_ascii_characters
    assert_equal '', ''.mb_chars.capitalize
    assert_equal 'Abc', 'abc'.mb_chars.capitalize
  end

  def test_respond_to_knows_which_methods_the_proxy_responds_to
    assert ''.mb_chars.respond_to?(:slice) # Defined on Chars
    assert ''.mb_chars.respond_to?(:capitalize!) # Defined on Chars
    assert ''.mb_chars.respond_to?(:gsub) # Defined on String
    assert !''.mb_chars.respond_to?(:undefined_method) # Not defined
  end

  def test_acts_like_string
    assert 'Bambi'.mb_chars.acts_like_string?
  end
end

# The default Multibyte Chars proxy has more features than the normal string implementation. Tests
# for the implementation of these features should run on all Ruby versions and shouldn't be tested
# through the proxy methods.
class MultibyteCharsExtrasTest < Test::Unit::TestCase
  include MultibyteTestHelpers

  if RUBY_VERSION >= '1.9'
    def test_tidy_bytes_is_broken_on_1_9_0
      assert_raises(ArgumentError) do
        assert_equal_codepoints [0xfffd].pack('U'), chars("\xef\xbf\xbd").tidy_bytes
      end
    end
  end

  def test_upcase_should_be_unicode_aware
    assert_equal "АБВГД\0F", chars("аБвгд\0f").upcase
    assert_equal 'こにちわ', chars('こにちわ').upcase
  end

  def test_downcase_should_be_unicode_aware
    assert_equal "абвгд\0f", chars("аБвгд\0f").downcase
    assert_equal 'こにちわ', chars('こにちわ').downcase
  end

  def test_capitalize_should_be_unicode_aware
    { 'аБвг аБвг' => 'Абвг абвг',
      'аБвг АБВГ' => 'Абвг абвг',
      'АБВГ АБВГ' => 'Абвг абвг',
      '' => '' }.each do |f,t|
        assert_equal t, chars(f).capitalize
    end
  end

  def test_composition_exclusion_is_set_up_properly
    # Normalization of DEVANAGARI LETTER QA breaks when composition exclusion isn't used correctly
    qa = [0x915, 0x93c].pack('U*')
    assert_equal qa, chars(qa).normalize(:c)
  end

  # Test for the Public Review Issue #29, bad explanation of composition might lead to a
  # bad implementation: http://www.unicode.org/review/pr-29.html
  def test_normalization_C_pri_29
    [
      [0x0B47, 0x0300, 0x0B3E],
      [0x1100, 0x0300, 0x1161]
    ].map { |c| c.pack('U*') }.each do |c|
      assert_equal_codepoints c, chars(c).normalize(:c)
    end
  end

  def test_normalization_shouldnt_strip_null_bytes
    null_byte_str = "Test\0test"

    assert_equal null_byte_str, chars(null_byte_str).normalize(:kc)
    assert_equal null_byte_str, chars(null_byte_str).normalize(:c)
    assert_equal null_byte_str, chars(null_byte_str).normalize(:d)
    assert_equal null_byte_str, chars(null_byte_str).normalize(:kd)
    assert_equal null_byte_str, chars(null_byte_str).decompose
    assert_equal null_byte_str, chars(null_byte_str).compose
  end

  def test_simple_normalization
    comp_str = [
      44,  # LATIN CAPITAL LETTER D
      307, # COMBINING DOT ABOVE
      328, # COMBINING OGONEK
      323 # COMBINING DOT BELOW
    ].pack("U*")

    assert_equal_codepoints '', chars('').normalize
    assert_equal_codepoints [44,105,106,328,323].pack("U*"), chars(comp_str).normalize(:kc).to_s
    assert_equal_codepoints [44,307,328,323].pack("U*"), chars(comp_str).normalize(:c).to_s
    assert_equal_codepoints [44,307,110,780,78,769].pack("U*"), chars(comp_str).normalize(:d).to_s
    assert_equal_codepoints [44,105,106,110,780,78,769].pack("U*"), chars(comp_str).normalize(:kd).to_s
  end

  def test_should_compute_grapheme_length
    [
      ['', 0],
      ['abc', 3],
      ['こにちわ', 4],
      [[0x0924, 0x094D, 0x0930].pack('U*'), 2],
      [%w(cr lf), 1],
      [%w(l l), 1],
      [%w(l v), 1],
      [%w(l lv), 1],
      [%w(l lvt), 1],
      [%w(lv v), 1],
      [%w(lv t), 1],
      [%w(v v), 1],
      [%w(v t), 1],
      [%w(lvt t), 1],
      [%w(t t), 1],
      [%w(n extend), 1],
      [%w(n n), 2],
      [%w(n cr lf n), 3],
      [%w(n l v t), 2]
    ].each do |input, expected_length|
      if input.kind_of?(Array)
        str = string_from_classes(input)
      else
        str = input
      end
      assert_equal expected_length, chars(str).g_length
    end
  end

  def test_tidy_bytes_should_tidy_bytes
    byte_string = "\270\236\010\210\245"
    tidy_string = [0xb8, 0x17e, 0x8, 0x2c6, 0xa5].pack('U*')
    ascii_padding = 'aa'
    utf8_padding = 'éé'

    assert_equal_codepoints tidy_string, chars(byte_string).tidy_bytes

    assert_equal_codepoints ascii_padding.dup.insert(1, tidy_string),
      chars(ascii_padding.dup.insert(1, byte_string)).tidy_bytes
    assert_equal_codepoints utf8_padding.dup.insert(2, tidy_string),
      chars(utf8_padding.dup.insert(2, byte_string)).tidy_bytes
    assert_nothing_raised { chars(byte_string).tidy_bytes.to_s.unpack('U*') }

    assert_equal_codepoints "\xC3\xA7", chars("\xE7").tidy_bytes # iso_8859_1: small c cedilla
    assert_equal_codepoints "\xE2\x80\x9C", chars("\x93").tidy_bytes # win_1252: left smart quote
    assert_equal_codepoints "\xE2\x82\xAC", chars("\x80").tidy_bytes # win_1252: euro
    assert_equal_codepoints "\x00", chars("\x00").tidy_bytes # null char
    assert_equal_codepoints [0xfffd].pack('U'), chars("\xef\xbf\xbd").tidy_bytes # invalid char
  rescue ArgumentError => e
    raise e if RUBY_VERSION < '1.9'
  end

  private

  def string_from_classes(classes)
    # Characters from the character classes as described in UAX #29
    character_from_class = {
      :l => 0x1100, :v => 0x1160, :t => 0x11A8, :lv => 0xAC00, :lvt => 0xAC01, :cr => 0x000D, :lf => 0x000A,
      :extend => 0x094D, :n => 0x64
    }
    classes.collect do |k|
      character_from_class[k.intern]
    end.pack('U*')
  end
end

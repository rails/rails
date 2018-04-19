# frozen_string_literal: true

require "abstract_unit"
require "multibyte_test_helpers"
require "active_support/core_ext/string/multibyte"

class MultibyteCharsTest < ActiveSupport::TestCase
  include MultibyteTestHelpers

  def setup
    @proxy_class = ActiveSupport::Multibyte::Chars
    @chars = @proxy_class.new UNICODE_STRING.dup
  end

  def test_wraps_the_original_string
    assert_equal UNICODE_STRING, @chars.to_s
    assert_equal UNICODE_STRING, @chars.wrapped_string
  end

  def test_should_allow_method_calls_to_string
    @chars.wrapped_string.singleton_class.class_eval { def __method_for_multibyte_testing; "result"; end }

    assert_nothing_raised do
      @chars.__method_for_multibyte_testing
    end
    assert_raise NoMethodError do
      @chars.__unknown_method
    end
  end

  def test_forwarded_method_calls_should_return_new_chars_instance
    @chars.wrapped_string.singleton_class.class_eval { def __method_for_multibyte_testing; "result"; end }

    assert_kind_of @proxy_class, @chars.__method_for_multibyte_testing
    assert_not_equal @chars.object_id, @chars.__method_for_multibyte_testing.object_id
  end

  def test_forwarded_bang_method_calls_should_return_the_original_chars_instance_when_result_is_not_nil
    @chars.wrapped_string.singleton_class.class_eval { def __method_for_multibyte_testing!; "result"; end }

    assert_kind_of @proxy_class, @chars.__method_for_multibyte_testing!
    assert_equal @chars.object_id, @chars.__method_for_multibyte_testing!.object_id
  end

  def test_forwarded_bang_method_calls_should_return_nil_when_result_is_nil
    @chars.wrapped_string.singleton_class.class_eval { def __method_for_multibyte_testing_that_returns_nil!; end }

    assert_nil @chars.__method_for_multibyte_testing_that_returns_nil!
  end

  def test_methods_are_forwarded_to_wrapped_string_for_byte_strings
    assert_equal BYTE_STRING.length, BYTE_STRING.mb_chars.length
  end

  def test_forwarded_method_with_non_string_result_should_be_returned_verbatim
    str = "".dup
    str.singleton_class.class_eval { def __method_for_multibyte_testing_with_integer_result; 1; end }
    @chars.wrapped_string.singleton_class.class_eval { def __method_for_multibyte_testing_with_integer_result; 1; end }

    assert_equal str.__method_for_multibyte_testing_with_integer_result, @chars.__method_for_multibyte_testing_with_integer_result
  end

  def test_should_concatenate
    mb_a = "a".dup.mb_chars
    mb_b = "b".dup.mb_chars
    assert_equal "ab", mb_a + "b"
    assert_equal "ab", "a" + mb_b
    assert_equal "ab", mb_a + mb_b

    assert_equal "ab", mb_a << "b"
    assert_equal "ab", "a".dup << mb_b
    assert_equal "abb", mb_a << mb_b
  end

  def test_consumes_utf8_strings
    assert @proxy_class.consumes?(UNICODE_STRING)
    assert @proxy_class.consumes?(ASCII_STRING)
    assert_not @proxy_class.consumes?(BYTE_STRING)
  end

  def test_concatenation_should_return_a_proxy_class_instance
    assert_equal ActiveSupport::Multibyte.proxy_class, ("a".mb_chars + "b").class
    assert_equal ActiveSupport::Multibyte.proxy_class, ("a".dup.mb_chars << "b").class
  end

  def test_ascii_strings_are_treated_at_utf8_strings
    assert_equal ActiveSupport::Multibyte.proxy_class, ASCII_STRING.mb_chars.class
  end

  def test_concatenate_should_return_proxy_instance
    assert(("a".mb_chars + "b").kind_of?(@proxy_class))
    assert(("a".mb_chars + "b".mb_chars).kind_of?(@proxy_class))
    assert(("a".dup.mb_chars << "b").kind_of?(@proxy_class))
    assert(("a".dup.mb_chars << "b".mb_chars).kind_of?(@proxy_class))
  end

  def test_should_return_string_as_json
    assert_equal UNICODE_STRING, @chars.as_json
  end
end

class MultibyteCharsUTF8BehaviourTest < ActiveSupport::TestCase
  include MultibyteTestHelpers

  def setup
    @chars = UNICODE_STRING.dup.mb_chars
    # Ruby 1.9 only supports basic whitespace
    @whitespace = "\n\t "
  end

  def test_split_should_return_an_array_of_chars_instances
    @chars.split(//).each do |character|
      assert_kind_of ActiveSupport::Multibyte.proxy_class, character
    end
  end

  %w{capitalize downcase lstrip reverse rstrip swapcase upcase}.each do |method|
    class_eval(<<-EOTESTS, __FILE__, __LINE__ + 1)
      def test_#{method}_bang_should_return_self_when_modifying_wrapped_string
        chars = ' él piDió Un bUen café '.dup
        assert_equal chars.object_id, chars.send("#{method}!").object_id
      end

      def test_#{method}_bang_should_change_wrapped_string
        original = ' él piDió Un bUen café '.dup
        proxy = chars(original.dup)
        proxy.send("#{method}!")
        assert_not_equal original, proxy.to_s
      end
    EOTESTS
  end

  def test_tidy_bytes_bang_should_return_self
    assert_equal @chars.object_id, @chars.tidy_bytes!.object_id
  end

  def test_tidy_bytes_bang_should_change_wrapped_string
    original = " Un bUen café \x92".dup
    proxy = chars(original.dup)
    proxy.tidy_bytes!
    assert_not_equal original, proxy.to_s
  end

  def test_unicode_string_should_have_utf8_encoding
    assert_equal Encoding::UTF_8, UNICODE_STRING.encoding
  end

  def test_identity
    assert_equal @chars, @chars
    assert @chars.eql?(@chars)
    assert_not @chars.eql?(UNICODE_STRING)
  end

  def test_string_methods_are_chainable
    assert chars("".dup).insert(0, "").kind_of?(ActiveSupport::Multibyte.proxy_class)
    assert chars("").rjust(1).kind_of?(ActiveSupport::Multibyte.proxy_class)
    assert chars("").ljust(1).kind_of?(ActiveSupport::Multibyte.proxy_class)
    assert chars("").center(1).kind_of?(ActiveSupport::Multibyte.proxy_class)
    assert chars("").rstrip.kind_of?(ActiveSupport::Multibyte.proxy_class)
    assert chars("").lstrip.kind_of?(ActiveSupport::Multibyte.proxy_class)
    assert chars("").strip.kind_of?(ActiveSupport::Multibyte.proxy_class)
    assert chars("").reverse.kind_of?(ActiveSupport::Multibyte.proxy_class)
    assert chars(" ").slice(0).kind_of?(ActiveSupport::Multibyte.proxy_class)
    assert chars("").limit(0).kind_of?(ActiveSupport::Multibyte.proxy_class)
    assert chars("").upcase.kind_of?(ActiveSupport::Multibyte.proxy_class)
    assert chars("").downcase.kind_of?(ActiveSupport::Multibyte.proxy_class)
    assert chars("").capitalize.kind_of?(ActiveSupport::Multibyte.proxy_class)
    assert chars("").normalize.kind_of?(ActiveSupport::Multibyte.proxy_class)
    assert chars("").decompose.kind_of?(ActiveSupport::Multibyte.proxy_class)
    assert chars("").compose.kind_of?(ActiveSupport::Multibyte.proxy_class)
    assert chars("").tidy_bytes.kind_of?(ActiveSupport::Multibyte.proxy_class)
    assert chars("").swapcase.kind_of?(ActiveSupport::Multibyte.proxy_class)
  end

  def test_should_be_equal_to_the_wrapped_string
    assert_equal UNICODE_STRING, @chars
    assert_equal @chars, UNICODE_STRING
  end

  def test_should_not_be_equal_to_an_other_string
    assert_not_equal @chars, "other"
    assert_not_equal "other", @chars
  end

  def test_sortability
    words = %w(builder armor zebra).sort_by(&:mb_chars)
    assert_equal %w(armor builder zebra), words
  end

  def test_should_return_character_offset_for_regexp_matches
    assert_nil(@chars =~ /wrong/u)
    assert_equal 0, (@chars =~ /こ/u)
    assert_equal 0, (@chars =~ /こに/u)
    assert_equal 1, (@chars =~ /に/u)
    assert_equal 2, (@chars =~ /ち/u)
    assert_equal 3, (@chars =~ /わ/u)
  end

  def test_should_use_character_offsets_for_insert_offsets
    assert_equal "", "".dup.mb_chars.insert(0, "")
    assert_equal "こわにちわ", @chars.insert(1, "わ")
    assert_equal "こわわわにちわ", @chars.insert(2, "わわ")
    assert_equal "わこわわわにちわ", @chars.insert(0, "わ")
    assert_equal "わこわわわにちわ", @chars.wrapped_string
  end

  def test_insert_should_be_destructive
    @chars.insert(1, "わ")
    assert_equal "こわにちわ", @chars
  end

  def test_insert_throws_index_error
    assert_raise(IndexError) { @chars.insert(-12, "わ") }
    assert_raise(IndexError) { @chars.insert(12, "わ") }
  end

  def test_should_know_if_one_includes_the_other
    assert_includes @chars, ""
    assert_includes @chars, "ち"
    assert_includes @chars, "わ"
    assert_not_includes @chars, "こちわ"
    assert_not_includes @chars, "a"
  end

  def test_include_raises_when_nil_is_passed
    assert_raises TypeError, NoMethodError, "Expected chars.include?(nil) to raise TypeError or NoMethodError" do
      @chars.include?(nil)
    end
  end

  def test_index_should_return_character_offset
    assert_nil @chars.index("u")
    assert_equal 0, @chars.index("こに")
    assert_equal 2, @chars.index("ち")
    assert_equal 2, @chars.index("ち", -2)
    assert_nil @chars.index("ち", -1)
    assert_equal 3, @chars.index("わ")
    assert_equal 5, "ééxééx".mb_chars.index("x", 4)
  end

  def test_rindex_should_return_character_offset
    assert_nil @chars.rindex("u")
    assert_equal 1, @chars.rindex("に")
    assert_equal 2, @chars.rindex("ち", -2)
    assert_nil @chars.rindex("ち", -3)
    assert_equal 6, "Café périferôl".mb_chars.rindex("é")
    assert_equal 13, "Café périferôl".mb_chars.rindex(/\w/u)
  end

  def test_indexed_insert_should_take_character_offsets
    @chars[2] = "a"
    assert_equal "こにaわ", @chars
    @chars[2] = "ηη"
    assert_equal "こにηηわ", @chars
    @chars[3, 2] = "λλλ"
    assert_equal "こにηλλλ", @chars
    @chars[1, 0] = "λ"
    assert_equal "こλにηλλλ", @chars
    @chars[4..6] = "ηη"
    assert_equal "こλにηηη", @chars
    @chars[/ηη/] = "λλλ"
    assert_equal "こλにλλλη", @chars
    @chars[/(λλ)(.)/, 2] = "α"
    assert_equal "こλにλλαη", @chars
    @chars["α"] = "¢"
    assert_equal "こλにλλ¢η", @chars
    @chars["λλ"] = "ααα"
    assert_equal "こλにααα¢η", @chars
  end

  def test_indexed_insert_should_raise_on_index_overflow
    before = @chars.to_s
    assert_raise(IndexError) { @chars[10] = "a" }
    assert_raise(IndexError) { @chars[10, 4] = "a" }
    assert_raise(IndexError) { @chars[/ii/] = "a" }
    assert_raise(IndexError) { @chars[/()/, 10] = "a" }
    assert_equal before, @chars
  end

  def test_indexed_insert_should_raise_on_range_overflow
    before = @chars.to_s
    assert_raise(RangeError) { @chars[10..12] = "a" }
    assert_equal before, @chars
  end

  def test_rjust_should_raise_argument_errors_on_bad_arguments
    assert_raise(ArgumentError) { @chars.rjust(10, "") }
    assert_raise(ArgumentError) { @chars.rjust }
  end

  def test_rjust_should_count_characters_instead_of_bytes
    assert_equal UNICODE_STRING, @chars.rjust(-3)
    assert_equal UNICODE_STRING, @chars.rjust(0)
    assert_equal UNICODE_STRING, @chars.rjust(4)
    assert_equal " #{UNICODE_STRING}", @chars.rjust(5)
    assert_equal "   #{UNICODE_STRING}", @chars.rjust(7)
    assert_equal "---#{UNICODE_STRING}", @chars.rjust(7, "-")
    assert_equal "ααα#{UNICODE_STRING}", @chars.rjust(7, "α")
    assert_equal "aba#{UNICODE_STRING}", @chars.rjust(7, "ab")
    assert_equal "αηα#{UNICODE_STRING}", @chars.rjust(7, "αη")
    assert_equal "αηαη#{UNICODE_STRING}", @chars.rjust(8, "αη")
  end

  def test_ljust_should_raise_argument_errors_on_bad_arguments
    assert_raise(ArgumentError) { @chars.ljust(10, "") }
    assert_raise(ArgumentError) { @chars.ljust }
  end

  def test_ljust_should_count_characters_instead_of_bytes
    assert_equal UNICODE_STRING, @chars.ljust(-3)
    assert_equal UNICODE_STRING, @chars.ljust(0)
    assert_equal UNICODE_STRING, @chars.ljust(4)
    assert_equal "#{UNICODE_STRING} ", @chars.ljust(5)
    assert_equal "#{UNICODE_STRING}   ", @chars.ljust(7)
    assert_equal "#{UNICODE_STRING}---", @chars.ljust(7, "-")
    assert_equal "#{UNICODE_STRING}ααα", @chars.ljust(7, "α")
    assert_equal "#{UNICODE_STRING}aba", @chars.ljust(7, "ab")
    assert_equal "#{UNICODE_STRING}αηα", @chars.ljust(7, "αη")
    assert_equal "#{UNICODE_STRING}αηαη", @chars.ljust(8, "αη")
  end

  def test_center_should_raise_argument_errors_on_bad_arguments
    assert_raise(ArgumentError) { @chars.center(10, "") }
    assert_raise(ArgumentError) { @chars.center }
  end

  def test_center_should_count_characters_instead_of_bytes
    assert_equal UNICODE_STRING, @chars.center(-3)
    assert_equal UNICODE_STRING, @chars.center(0)
    assert_equal UNICODE_STRING, @chars.center(4)
    assert_equal "#{UNICODE_STRING} ", @chars.center(5)
    assert_equal " #{UNICODE_STRING} ", @chars.center(6)
    assert_equal " #{UNICODE_STRING}  ", @chars.center(7)
    assert_equal "--#{UNICODE_STRING}--", @chars.center(8, "-")
    assert_equal "--#{UNICODE_STRING}---", @chars.center(9, "-")
    assert_equal "αα#{UNICODE_STRING}αα", @chars.center(8, "α")
    assert_equal "αα#{UNICODE_STRING}ααα", @chars.center(9, "α")
    assert_equal "a#{UNICODE_STRING}ab", @chars.center(7, "ab")
    assert_equal "ab#{UNICODE_STRING}ab", @chars.center(8, "ab")
    assert_equal "abab#{UNICODE_STRING}abab", @chars.center(12, "ab")
    assert_equal "α#{UNICODE_STRING}αη", @chars.center(7, "αη")
    assert_equal "αη#{UNICODE_STRING}αη", @chars.center(8, "αη")
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
    assert_equal 0, "".mb_chars.size
    assert_equal 4, @chars.size
    assert_equal 4, @chars.length
    assert_equal 5, ASCII_STRING.mb_chars.size
  end

  def test_reverse_reverses_characters
    assert_equal "", "".mb_chars.reverse
    assert_equal "わちにこ", @chars.reverse
  end

  def test_reverse_should_work_with_normalized_strings
    str = "bös"
    reversed_str = "söb"
    assert_equal chars(reversed_str).normalize(:kc), chars(str).normalize(:kc).reverse
    assert_equal chars(reversed_str).normalize(:c), chars(str).normalize(:c).reverse
    assert_equal chars(reversed_str).normalize(:d), chars(str).normalize(:d).reverse
    assert_equal chars(reversed_str).normalize(:kd), chars(str).normalize(:kd).reverse
    assert_equal chars(reversed_str).decompose, chars(str).decompose.reverse
    assert_equal chars(reversed_str).compose, chars(str).compose.reverse
  end

  def test_slice_should_take_character_offsets
    assert_nil "".mb_chars.slice(0)
    assert_equal "こ", @chars.slice(0)
    assert_equal "わ", @chars.slice(3)
    assert_nil "".mb_chars.slice(-1..1)
    assert_nil "".mb_chars.slice(-1, 1)
    assert_equal "", "".mb_chars.slice(0..10)
    assert_equal "にちわ", @chars.slice(1..3)
    assert_equal "にちわ", @chars.slice(1, 3)
    assert_equal "こ", @chars.slice(0, 1)
    assert_equal "ちわ", @chars.slice(2..10)
    assert_equal "", @chars.slice(4..10)
    assert_equal "に", @chars.slice(/に/u)
    assert_equal "にち", @chars.slice(/に./u)
    assert_nil @chars.slice(/unknown/u)
    assert_equal "にち", @chars.slice(/(にち)/u, 1)
    assert_nil @chars.slice(/(にち)/u, 2)
    assert_nil @chars.slice(7..6)
  end

  def test_slice_bang_returns_sliced_out_substring
    assert_equal "にち", @chars.slice!(1..2)
  end

  def test_slice_bang_returns_nil_on_out_of_bound_arguments
    assert_nil @chars.mb_chars.slice!(9..10)
  end

  def test_slice_bang_removes_the_slice_from_the_receiver
    chars = "úüù".dup.mb_chars
    chars.slice!(0, 2)
    assert_equal "ù", chars
  end

  def test_slice_bang_returns_nil_and_does_not_modify_receiver_if_out_of_bounds
    string = "úüù".dup
    chars = string.mb_chars
    assert_nil chars.slice!(4, 5)
    assert_equal "úüù", chars
    assert_equal "úüù", string
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
    assert_equal "", "".mb_chars.upcase
    assert_equal "ABC", "aBc".mb_chars.upcase
  end

  def test_downcase_should_downcase_ascii_characters
    assert_equal "", "".mb_chars.downcase
    assert_equal "abc", "aBc".mb_chars.downcase
  end

  def test_swapcase_should_swap_ascii_characters
    assert_equal "", "".mb_chars.swapcase
    assert_equal "AbC", "aBc".mb_chars.swapcase
  end

  def test_capitalize_should_work_on_ascii_characters
    assert_equal "", "".mb_chars.capitalize
    assert_equal "Abc", "abc".mb_chars.capitalize
  end

  def test_titleize_should_work_on_ascii_characters
    assert_equal "", "".mb_chars.titleize
    assert_equal "Abc Abc", "abc abc".mb_chars.titleize
  end

  def test_respond_to_knows_which_methods_the_proxy_responds_to
    assert_respond_to "".mb_chars, :slice # Defined on Chars
    assert_respond_to "".mb_chars, :capitalize! # Defined on Chars
    assert_respond_to "".mb_chars, :gsub # Defined on String
    assert_not_respond_to "".mb_chars, :undefined_method # Not defined
  end

  def test_method_works_for_proxyed_methods
    assert_equal "ll", "hello".mb_chars.method(:slice).call(2..3) # Defined on Chars
    chars = "hello".mb_chars
    assert_equal "Hello", chars.method(:capitalize!).call # Defined on Chars
    assert_equal "Hello", chars
    assert_equal "jello", "hello".mb_chars.method(:gsub).call(/h/, "j") # Defined on String
    assert_raise(NameError) { "".mb_chars.method(:undefined_method) } # Not defined
  end

  def test_acts_like_string
    assert_predicate "Bambi".mb_chars, :acts_like_string?
  end
end

# The default Multibyte Chars proxy has more features than the normal string implementation. Tests
# for the implementation of these features should run on all Ruby versions and shouldn't be tested
# through the proxy methods.
class MultibyteCharsExtrasTest < ActiveSupport::TestCase
  include MultibyteTestHelpers

  def test_upcase_should_be_unicode_aware
    assert_equal "АБВГД\0F", chars("аБвгд\0f").upcase
    assert_equal "こにちわ", chars("こにちわ").upcase
  end

  def test_downcase_should_be_unicode_aware
    assert_equal "абвгд\0f", chars("аБвгд\0F").downcase
    assert_equal "こにちわ", chars("こにちわ").downcase
  end

  def test_swapcase_should_be_unicode_aware
    assert_equal "аaéÜ\0f", chars("АAÉü\0F").swapcase
    assert_equal "こにちわ", chars("こにちわ").swapcase
  end

  def test_capitalize_should_be_unicode_aware
    { "аБвг аБвг" => "Абвг абвг",
      "аБвг АБВГ" => "Абвг абвг",
      "АБВГ АБВГ" => "Абвг абвг",
      "" => "" }.each do |f, t|
      assert_equal t, chars(f).capitalize
    end
  end

  def test_titleize_should_be_unicode_aware
    assert_equal "Él Que Se Enteró", chars("ÉL QUE SE ENTERÓ").titleize
    assert_equal "Абвг Абвг", chars("аБвг аБвг").titleize
  end

  def test_titleize_should_not_affect_characters_that_do_not_case_fold
    assert_equal "日本語", chars("日本語").titleize
  end

  def test_limit_should_not_break_on_blank_strings
    example = chars("")
    assert_equal example, example.limit(0)
    assert_equal example, example.limit(1)
  end

  def test_limit_should_work_on_a_multibyte_string
    example = chars(UNICODE_STRING)
    bytesize = UNICODE_STRING.bytesize

    assert_equal UNICODE_STRING, example.limit(bytesize)
    assert_equal "", example.limit(0)
    assert_equal "", example.limit(1)
    assert_equal "こ", example.limit(3)
    assert_equal "こに", example.limit(6)
    assert_equal "こに", example.limit(8)
    assert_equal "こにち", example.limit(9)
    assert_equal "こにちわ", example.limit(50)
  end

  def test_limit_should_work_on_an_ascii_string
    ascii = chars(ASCII_STRING)
    assert_equal ASCII_STRING, ascii.limit(ASCII_STRING.length)
    assert_equal "", ascii.limit(0)
    assert_equal "o", ascii.limit(1)
    assert_equal "oh", ascii.limit(2)
    assert_equal "ohay", ascii.limit(4)
    assert_equal "ohayo", ascii.limit(50)
  end

  def test_limit_should_keep_under_the_specified_byte_limit
    example = chars(UNICODE_STRING)
    (1..UNICODE_STRING.length).each do |limit|
      assert example.limit(limit).to_s.length <= limit
    end
  end

  def test_composition_exclusion_is_set_up_properly
    # Normalization of DEVANAGARI LETTER QA breaks when composition exclusion isn't used correctly
    qa = [0x915, 0x93c].pack("U*")
    assert_equal qa, chars(qa).normalize(:c)
  end

  # Test for the Public Review Issue #29, bad explanation of composition might lead to a
  # bad implementation: http://www.unicode.org/review/pr-29.html
  def test_normalization_C_pri_29
    [
      [0x0B47, 0x0300, 0x0B3E],
      [0x1100, 0x0300, 0x1161]
    ].map { |c| c.pack("U*") }.each do |c|
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

    assert_equal_codepoints "", chars("").normalize
    assert_equal_codepoints [44, 105, 106, 328, 323].pack("U*"), chars(comp_str).normalize(:kc).to_s
    assert_equal_codepoints [44, 307, 328, 323].pack("U*"), chars(comp_str).normalize(:c).to_s
    assert_equal_codepoints [44, 307, 110, 780, 78, 769].pack("U*"), chars(comp_str).normalize(:d).to_s
    assert_equal_codepoints [44, 105, 106, 110, 780, 78, 769].pack("U*"), chars(comp_str).normalize(:kd).to_s
  end

  def test_should_compute_grapheme_length
    [
      ["", 0],
      ["abc", 3],
      ["こにちわ", 4],
      [[0x0924, 0x094D, 0x0930].pack("U*"), 2],
      # GB3
      [%w(cr lf), 1],
      # GB4
      [%w(cr n), 2],
      [%w(lf n), 2],
      [%w(control n), 2],
      [%w(cr extend), 2],
      [%w(lf extend), 2],
      [%w(control extend), 2],
      # GB 5
      [%w(n cr), 2],
      [%w(n lf), 2],
      [%w(n control), 2],
      [%w(extend cr), 2],
      [%w(extend lf), 2],
      [%w(extend control), 2],
      # GB 6
      [%w(l l), 1],
      [%w(l v), 1],
      [%w(l lv), 1],
      [%w(l lvt), 1],
      # GB7
      [%w(lv v), 1],
      [%w(lv t), 1],
      [%w(v v), 1],
      [%w(v t), 1],
      # GB8
      [%w(lvt t), 1],
      [%w(t t), 1],
      # GB8a
      [%w(r r), 1],
      # GB9
      [%w(n extend), 1],
      # GB9a
      [%w(n spacingmark), 1],
      # GB10
      [%w(n n), 2],
      # Other
      [%w(n cr lf n), 3],
      [%w(n l v t), 2],
      [%w(cr extend n), 3],
    ].each do |input, expected_length|
      if input.kind_of?(Array)
        str = string_from_classes(input)
      else
        str = input
      end
      assert_equal expected_length, chars(str).grapheme_length, input.inspect
    end
  end

  def test_tidy_bytes_should_tidy_bytes
    single_byte_cases = {
      "\x21" => "!",   # Valid ASCII byte, low
      "\x41" => "A",   # Valid ASCII byte, mid
      "\x7E" => "~",   # Valid ASCII byte, high
      "\x80" => "€",   # Continuation byte, low (cp125)
      "\x94" => "”",   # Continuation byte, mid (cp125)
      "\x9F" => "Ÿ",   # Continuation byte, high (cp125)
      "\xC0" => "À",   # Overlong encoding, start of 2-byte sequence, but codepoint < 128
      "\xC1" => "Á",   # Overlong encoding, start of 2-byte sequence, but codepoint < 128
      "\xC2" => "Â",   # Start of 2-byte sequence, low
      "\xC8" => "È",   # Start of 2-byte sequence, mid
      "\xDF" => "ß",   # Start of 2-byte sequence, high
      "\xE0" => "à",   # Start of 3-byte sequence, low
      "\xE8" => "è",   # Start of 3-byte sequence, mid
      "\xEF" => "ï",   # Start of 3-byte sequence, high
      "\xF0" => "ð",   # Start of 4-byte sequence
      "\xF1" => "ñ",   # Unused byte
      "\xFF" => "ÿ",   # Restricted byte
      "\x00" => "\x00" # null char
    }

    single_byte_cases.each do |bad, good|
      assert_equal good, chars(bad).tidy_bytes.to_s
      assert_equal "#{good}#{good}", chars("#{bad}#{bad}").tidy_bytes
      assert_equal "#{good}#{good}#{good}", chars("#{bad}#{bad}#{bad}").tidy_bytes
      assert_equal "#{good}a", chars("#{bad}a").tidy_bytes
      assert_equal "#{good}á", chars("#{bad}á").tidy_bytes
      assert_equal "a#{good}a", chars("a#{bad}a").tidy_bytes
      assert_equal "á#{good}á", chars("á#{bad}á").tidy_bytes
      assert_equal "a#{good}", chars("a#{bad}").tidy_bytes
      assert_equal "á#{good}", chars("á#{bad}").tidy_bytes
    end

    byte_string = "\270\236\010\210\245"
    tidy_string = [0xb8, 0x17e, 0x8, 0x2c6, 0xa5].pack("U*")
    assert_equal_codepoints tidy_string, chars(byte_string).tidy_bytes
    assert_nothing_raised { chars(byte_string).tidy_bytes.to_s.unpack("U*") }

    # UTF-8 leading byte followed by too few continuation bytes
    assert_equal_codepoints "\xc3\xb0\xc2\xa5\xc2\xa4\x21", chars("\xf0\xa5\xa4\x21").tidy_bytes
  end

  def test_tidy_bytes_should_forcibly_tidy_bytes_if_specified
    byte_string = "\xF0\xA5\xA4\xA4" # valid as both CP-1252 and UTF-8, but with different interpretations.
    assert_not_equal "ð¥¤¤", chars(byte_string).tidy_bytes
    # Forcible conversion to UTF-8
    assert_equal "ð¥¤¤", chars(byte_string).tidy_bytes(true)
  end

  def test_class_is_not_forwarded
    assert_equal BYTE_STRING.dup.mb_chars.class, ActiveSupport::Multibyte::Chars
  end

  private

    def string_from_classes(classes)
      # Characters from the character classes as described in UAX #29
      character_from_class = {
        l: 0x1100, v: 0x1160, t: 0x11A8, lv: 0xAC00, lvt: 0xAC01, cr: 0x000D, lf: 0x000A,
        extend: 0x094D, n: 0x64, spacingmark: 0x0903, r: 0x1F1E6, control: 0x0001
      }
      classes.collect do |k|
        character_from_class[k.intern]
      end.pack("U*")
    end
end

class MultibyteInternalsTest < ActiveSupport::TestCase
  include MultibyteTestHelpers

  test "Chars translates a character offset to a byte offset" do
    example = chars("Puisque c'était son erreur, il m'a aidé")
    [
      [0, 0],
      [3, 3],
      [12, 11],
      [14, 13],
      [41, 39]
    ].each do |byte_offset, character_offset|
      assert_equal character_offset, example.send(:translate_offset, byte_offset),
        "Expected byte offset #{byte_offset} to translate to #{character_offset}"
    end
  end
end

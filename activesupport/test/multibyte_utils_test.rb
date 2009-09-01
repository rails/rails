require 'abstract_unit'

class MultibyteUtilsTest < Test::Unit::TestCase

  def test_valid_character_returns_an_expression_for_the_current_encoding
    with_kcode('None') do
      assert_nil ActiveSupport::Multibyte.valid_character
    end
    with_kcode('UTF8') do
      assert_equal ActiveSupport::Multibyte::VALID_CHARACTER['UTF-8'], ActiveSupport::Multibyte.valid_character
    end
    with_kcode('SJIS') do
      assert_equal ActiveSupport::Multibyte::VALID_CHARACTER['Shift_JIS'], ActiveSupport::Multibyte.valid_character
    end
  end

  def test_verify_verifies_ASCII_strings_are_properly_encoded
    with_kcode('None') do
      examples.each do |example|
        assert ActiveSupport::Multibyte.verify(example)
      end
    end
  end

  def test_verify_verifies_UTF_8_strings_are_properly_encoded
    with_kcode('UTF8') do
      assert ActiveSupport::Multibyte.verify(example('valid UTF-8'))
      assert !ActiveSupport::Multibyte.verify(example('invalid UTF-8'))
    end
  end

  def test_verify_verifies_Shift_JIS_strings_are_properly_encoded
    with_kcode('SJIS') do
      assert ActiveSupport::Multibyte.verify(example('valid Shift-JIS'))
      assert !ActiveSupport::Multibyte.verify(example('invalid Shift-JIS'))
    end
  end

  def test_verify_bang_raises_an_exception_when_it_finds_an_invalid_character
    with_kcode('UTF8') do
      assert_raises(ActiveSupport::Multibyte::Handlers::EncodingError) do
        ActiveSupport::Multibyte.verify!(example('invalid UTF-8'))
      end
    end
  end

  def test_verify_bang_doesnt_raise_an_exception_when_the_encoding_is_valid
    with_kcode('UTF8') do
      assert_nothing_raised do
        ActiveSupport::Multibyte.verify!(example('valid UTF-8'))
      end
    end
  end

  def test_clean_leaves_ASCII_strings_intact
    with_kcode('None') do
      [
        'word', "\270\236\010\210\245"
      ].each do |string|
        assert_equal string, ActiveSupport::Multibyte.clean(string)
      end
    end
  end

  def test_clean_cleans_invalid_characters_from_UTF_8_encoded_strings
    with_kcode('UTF8') do
      cleaned_utf8 = [8].pack('C*')
      assert_equal example('valid UTF-8'), ActiveSupport::Multibyte.clean(example('valid UTF-8'))
      assert_equal cleaned_utf8, ActiveSupport::Multibyte.clean(example('invalid UTF-8'))
    end
  end

  def test_clean_cleans_invalid_characters_from_Shift_JIS_encoded_strings
    with_kcode('SJIS') do
      cleaned_sjis = [184, 0, 136, 165].pack('C*')
      assert_equal example('valid Shift-JIS'), ActiveSupport::Multibyte.clean(example('valid Shift-JIS'))
      assert_equal cleaned_sjis, ActiveSupport::Multibyte.clean(example('invalid Shift-JIS'))
    end
  end

  private

  STRINGS = {
    'valid ASCII'       => [65, 83, 67, 73, 73].pack('C*'),
    'invalid ASCII'     => [128].pack('C*'),
    'valid UTF-8'       => [227, 129, 147, 227, 129, 171, 227, 129, 161, 227, 130, 143].pack('C*'),
    'invalid UTF-8'     => [184, 158, 8, 136, 165].pack('C*'),
    'valid Shift-JIS'   => [131, 122, 129, 91, 131, 128].pack('C*'),
    'invalid Shift-JIS' => [184, 158, 8, 0, 255, 136, 165].pack('C*')
  }

  def example(key)
    STRINGS[key]
  end

  def examples
    STRINGS.values
  end

  def with_kcode(code)
    before = $KCODE
    $KCODE = code
    yield
    $KCODE = before
  end
end
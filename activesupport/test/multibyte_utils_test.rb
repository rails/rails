# encoding: utf-8

require 'abstract_unit'
require 'multibyte_test_helpers'

class MultibyteUtilsTest < ActiveSupport::TestCase
  include MultibyteTestHelpers

  test "valid_character returns an expression for the current encoding" do
    with_encoding('None') do
      assert_nil ActiveSupport::Multibyte.valid_character
    end
    with_encoding('UTF8') do
      assert_equal ActiveSupport::Multibyte::VALID_CHARACTER['UTF-8'], ActiveSupport::Multibyte.valid_character
    end
    with_encoding('SJIS') do
      assert_equal ActiveSupport::Multibyte::VALID_CHARACTER['Shift_JIS'], ActiveSupport::Multibyte.valid_character
    end
  end

  test "verify verifies ASCII strings are properly encoded" do
    with_encoding('None') do
      examples.each do |example|
        assert ActiveSupport::Multibyte.verify(example)
      end
    end
  end

  test "verify verifies UTF-8 strings are properly encoded" do
    with_encoding('UTF8') do
      assert ActiveSupport::Multibyte.verify(example('valid UTF-8'))
      assert !ActiveSupport::Multibyte.verify(example('invalid UTF-8'))
    end
  end

  test "verify verifies Shift-JIS strings are properly encoded" do
    with_encoding('SJIS') do
      assert ActiveSupport::Multibyte.verify(example('valid Shift-JIS'))
      assert !ActiveSupport::Multibyte.verify(example('invalid Shift-JIS'))
    end
  end

  test "verify! raises an exception when it finds an invalid character" do
    with_encoding('UTF8') do
      assert_raises(ActiveSupport::Multibyte::EncodingError) do
        ActiveSupport::Multibyte.verify!(example('invalid UTF-8'))
      end
    end
  end

  test "verify! doesn't raise an exception when the encoding is valid" do
    with_encoding('UTF8') do
      assert_nothing_raised do
        ActiveSupport::Multibyte.verify!(example('valid UTF-8'))
      end
    end
  end

  if RUBY_VERSION < '1.9'
    test "clean leaves ASCII strings intact" do
      with_encoding('None') do
        [
          'word', "\270\236\010\210\245"
        ].each do |string|
          assert_equal string, ActiveSupport::Multibyte.clean(string)
        end
      end
    end

    test "clean cleans invalid characters from UTF-8 encoded strings" do
      with_encoding('UTF8') do
        cleaned_utf8 = [8].pack('C*')
        assert_equal example('valid UTF-8'), ActiveSupport::Multibyte.clean(example('valid UTF-8'))
        assert_equal cleaned_utf8, ActiveSupport::Multibyte.clean(example('invalid UTF-8'))
      end
    end

    test "clean cleans invalid characters from Shift-JIS encoded strings" do
      with_encoding('SJIS') do
        cleaned_sjis = [184, 0, 136, 165].pack('C*')
        assert_equal example('valid Shift-JIS'), ActiveSupport::Multibyte.clean(example('valid Shift-JIS'))
        assert_equal cleaned_sjis, ActiveSupport::Multibyte.clean(example('invalid Shift-JIS'))
      end
    end
  else
    test "clean is a no-op" do
      with_encoding('UTF8') do
        assert_equal example('invalid Shift-JIS'), ActiveSupport::Multibyte.clean(example('invalid Shift-JIS'))
      end
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

  if Kernel.const_defined?(:Encoding)
    def example(key)
      STRINGS[key].force_encoding(Encoding.default_external)
    end

    def examples
      STRINGS.values.map { |s| s.force_encoding(Encoding.default_external) }
    end
  else
    def example(key)
      STRINGS[key]
    end

    def examples
      STRINGS.values
    end
  end

  if 'string'.respond_to?(:encoding)
    KCODE_TO_ENCODING = Hash.new(Encoding::BINARY).
      update('UTF8' => Encoding::UTF_8, 'SJIS' => Encoding::Shift_JIS)

    def with_encoding(enc)
      before = Encoding.default_external
      silence_warnings { Encoding.default_external = KCODE_TO_ENCODING[enc] }

      yield

      silence_warnings { Encoding.default_external = before }
    end
  else
    alias with_encoding with_kcode
  end
end

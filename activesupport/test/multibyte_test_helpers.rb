# frozen_string_literal: true

module MultibyteTestHelpers
  # We use Symbol#to_s to create these strings so warnings are emitted if they are mutated
  UNICODE_STRING = :"こにちわ".to_s
  ASCII_STRING = :"ohayo".to_s
  BYTE_STRING = "\270\236\010\210\245".b.freeze

  def chars(str)
    assert_deprecated ActiveSupport.deprecator do
      ActiveSupport::Multibyte::Chars.new(str)
    end
  end

  def inspect_codepoints(str)
    str.to_s.unpack("U*").map { |cp| cp.to_s(16) }.join(" ")
  end

  def assert_equal_codepoints(expected, actual, message = nil)
    assert_equal(inspect_codepoints(expected), inspect_codepoints(actual), message)
  end
end

# encoding: utf-8

module MultibyteTestHelpers
  UNICODE_STRING = 'こにちわ'
  ASCII_STRING = 'ohayo'
  BYTE_STRING = "\270\236\010\210\245"

  def chars(str)
    ActiveSupport::Multibyte::Chars.new(str)
  end

  def inspect_codepoints(str)
    str.to_s.unpack("U*").map{|cp| cp.to_s(16) }.join(' ')
  end

  def assert_equal_codepoints(expected, actual, message=nil)
    assert_equal(inspect_codepoints(expected), inspect_codepoints(actual), message)
  end
end
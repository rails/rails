require 'base64'

module ActiveSupport
  Base64 = ::Base64

  # *DEPRECATED*: Use +Base64.strict_encode64+ instead.
  #
  # Encodes the value as base64 without the newline breaks. This makes the base64 encoding readily usable as URL parameters
  # or memcache keys without further processing.
  #
  #  ActiveSupport::Base64.encode64s("Original unencoded string")
  #  # => "T3JpZ2luYWwgdW5lbmNvZGVkIHN0cmluZw=="
  def Base64.encode64s(value)
    ActiveSupport::Deprecation.warn "encode64s " \
      "is deprecated. Use Base64.strict_encode64 instead", caller
    strict_encode64(value)
  end
end

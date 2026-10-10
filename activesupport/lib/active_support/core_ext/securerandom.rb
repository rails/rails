# :markup: markdown
# frozen_string_literal: true

require "securerandom"

module SecureRandom
  BASE58_ALPHABET = ("0".."9").to_a + ("A".."Z").to_a + ("a".."z").to_a - ["0", "O", "I", "l"]
  BASE36_ALPHABET = ("0".."9").to_a + ("a".."z").to_a
  BASE30_ALPHABET = ("0".."9").to_a + ("A".."Z").to_a - ["0", "1", "I", "L", "O", "U"]

  # SecureRandom.base58 generates a random base58 string.
  #
  # The argument *n* specifies the length of the random string to be generated.
  #
  # If *n* is not specified or is `nil`, 16 is assumed. It may be larger in the future.
  #
  # The result may contain alphanumeric characters except 0, O, I, and l.
  #
  # ```
  # p SecureRandom.base58 # => "4kUgL2pdQMSCQtjE"
  # p SecureRandom.base58(24) # => "77TMHrHJFvFDwodq8w7Ev2m7"
  # ```
  def self.base58(n = 16)
    alphanumeric(n, chars: BASE58_ALPHABET)
  end

  # SecureRandom.base36 generates a random base36 string in lowercase.
  #
  # The argument *n* specifies the length of the random string to be generated.
  #
  # If *n* is not specified or is `nil`, 16 is assumed. It may be larger in the future.
  # This method can be used over `base58` if a deterministic case key is necessary.
  #
  # The result will contain alphanumeric characters in lowercase.
  #
  # ```
  # p SecureRandom.base36 # => "4kugl2pdqmscqtje"
  # p SecureRandom.base36(24) # => "77tmhrhjfvfdwodq8w7ev2m7"
  # ```
  def self.base36(n = 16)
    alphanumeric(n, chars: BASE36_ALPHABET)
  end

  # SecureRandom.base30 generates a random base30 string in uppercase based on the Crockford alphabet.
  #
  # The argument *n* specifies the length of the random string to be generated.
  #
  # If *n* is not specified or is `nil`, 16 is assumed. It may be larger in the future.
  # This method can be used over `base58` if a case-insensitive key that's unambiguous to humans is necessary.
  #
  # The result may contain alphanumeric characters in uppercase except 0, 1, I, L, O, and U.
  #
  # The omission of 0 and 1 from the Crockford alphabet makes it even simpler for humans to read and
  # transfer strings, as there is now no chance of confusion of 0, O, 1, and I/L, even when rendered
  # in typefaces that have less-obvious differences between them than common mono-spaced typefaces.
  #
  # ```
  # p SecureRandom.base30 # => "FYWCJTEVA78KM8C3"
  # p SecureRandom.base30(24) # => "SVE9HA8Q3SXE5AVB63JMNVGS"
  # ```
  def self.base30(n = 16)
    alphanumeric(n, chars: BASE30_ALPHABET)
  end
end

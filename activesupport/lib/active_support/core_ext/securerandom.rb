require 'securerandom'

module SecureRandom
  BASE58_ALPHABET = %w(1 2 3 4 5 6 7 8 9
                       A B C D E F G H J K L M N P Q R S T U V W X Y Z
                       a b c d e f g h i j k m n o p q r s t u v w x y z).freeze

  # SecureRandom.base58 generates a random base58 string.
  #
  # The argument _n_ specifies the length, of the random string to be generated.
  #
  # If _n_ is not specified or is nil, 16 is assumed. It may be larger in the future.
  #
  # The result may contain alphanumeric characters except 0, O, I and l
  #
  #   p SecureRandom.base58 # => "4kUgL2pdQMSCQtjE"
  #   p SecureRandom.base58(24) # => "77TMHrHJFvFDwodq8w7Ev2m7"
  #
  def self.base58(n = 16)
    SecureRandom.random_bytes(n).unpack("C*").map do |byte|
      idx = byte % 64
      idx = SecureRandom.random_number(58) if idx >= 58
      BASE58_ALPHABET[idx]
    end.join
  end
end

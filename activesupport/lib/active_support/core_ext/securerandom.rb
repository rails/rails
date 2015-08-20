require 'securerandom'

module SecureRandom
  BASE58_ALPHABET = ('0'..'9').to_a  + ('A'..'Z').to_a + ('a'..'z').to_a - ['0', 'O', 'I', 'l']
  # SecureRandom.base58 generates a random base58 string.
  #
  # The argument _n_ specifies the length, of the random string to be generated.
  #
  # If _n_ is not specified or is nil, 16 is assumed. It may be larger in the future.
  #
  # The result may contain alphanumeric characters except 0, O, I and l
  #
  #   p SecureRandom.base58 #=> "4kUgL2pdQMSCQtjE"
  #   p SecureRandom.base58(24) #=> "77TMHrHJFvFDwodq8w7Ev2m7"
  #
  def self.base58(n = 16)
    (0..n).map { BASE58_ALPHABET[SecureRandom.random_number(58)] }.join
  end
end

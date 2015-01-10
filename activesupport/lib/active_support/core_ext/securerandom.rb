require 'securerandom'

module SecureRandom
  BASE58_EXCLUDES = "\+\/0=IOl"
  private_constant :BASE58_EXCLUDES

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
    str = base64(n)
    str.delete!(BASE58_EXCLUDES)

    while str.length < n
      append = base64(n)
      append.delete!(BASE58_EXCLUDES)

      str << append
    end

    str[0, n]
  end
end

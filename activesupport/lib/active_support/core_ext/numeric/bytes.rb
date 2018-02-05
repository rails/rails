# frozen_string_literal: true

class Numeric
  KILOBYTE  = 1024
  MEGABYTE  = KILOBYTE * 1024
  GIGABYTE  = MEGABYTE * 1024
  TERABYTE  = GIGABYTE * 1024
  PETABYTE  = TERABYTE * 1024
  EXABYTE   = PETABYTE * 1024
  ZETTABYTE = EXABYTE * 1024
  YOTTABYTE = ZETTABYTE * 1024

  # Enables the use of byte calculations and declarations, like 45.bytes + 2.6.megabytes
  #
  #   2.bytes # => 2
  def bytes
    self
  end
  alias :byte :bytes

  # Returns the number of bytes equivalent to the kilobytes provided.
  #
  #   2.kilobytes # => 2048
  def kilobytes
    self * KILOBYTE
  end
  alias :kilobyte :kilobytes

  # Returns the number of bytes equivalent to the megabytes provided.
  #
  #   2.megabytes # => 2_097_152
  def megabytes
    self * MEGABYTE
  end
  alias :megabyte :megabytes

  # Returns the number of bytes equivalent to the gigabytes provided.
  #
  #   2.gigabytes # => 2_147_483_648
  def gigabytes
    self * GIGABYTE
  end
  alias :gigabyte :gigabytes

  # Returns the number of bytes equivalent to the terabytes provided.
  #
  #   2.terabytes # => 2_199_023_255_552
  def terabytes
    self * TERABYTE
  end
  alias :terabyte :terabytes

  # Returns the number of bytes equivalent to the petabytes provided.
  #
  #   2.petabytes # => 2_251_799_813_685_248
  def petabytes
    self * PETABYTE
  end
  alias :petabyte :petabytes

  # Returns the number of bytes equivalent to the exabytes provided.
  #
  #   2.exabytes # => 2_305_843_009_213_693_952
  def exabytes
    self * EXABYTE
  end
  alias :exabyte :exabytes

  # Returns the number of bytes equivalent to the zettabytes provided.
  #
  #   2.zettabytes # => 2_361_183_241_434_822_606_848
  def zettabytes
    self * ZETTABYTE
  end
  alias :zettabyte :zettabytes

  # Returns the number of bytes equivalent to the yottabytes provided.
  #
  #   2.yottabytes # => 2_417_851_639_229_258_349_412_352
  def yottabytes
    self * YOTTABYTE
  end
  alias :yottabyte :yottabytes
end

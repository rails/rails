class Numeric
  KILOBYTE  = 1000
  MEGABYTE  = KILOBYTE  * 1000
  GIGABYTE  = MEGABYTE  * 1000
  TERABYTE  = GIGABYTE  * 1000
  PETABYTE  = TERABYTE  * 1000
  EXABYTE   = PETABYTE  * 1000
  ZETTABYTE = EXABYTE   * 1000
  YOTTABYTE = ZETTABYTE * 1000

  KIBIBYTE = 1024
  MEBIBYTE = KIBIBYTE * 1024
  GIBIBYTE = MEBIBYTE * 1024
  TEBIBYTE = GIBIBYTE * 1024
  PEBIBYTE = TEBIBYTE * 1024
  EXBIBYTE = PEBIBYTE * 1024
  ZEBIBYTE = EXBIBYTE * 1024
  YOBIBYTE = ZEBIBYTE * 1024

  # Enables the use of byte calculations and declarations, like 45.bytes + 2.6.megabytes
  #
  #   2.bytes # => 2
  def bytes
    self
  end
  alias :byte :bytes

  # Returns the number of bytes equivalent to the kilobytes provided.
  #
  #   2.kilobytes # => 2000
  def kilobytes
    self * KILOBYTE
  end
  alias :kilobyte :kilobytes

  # Returns the number of bytes equivalent to the kibibytes provided.
  #
  #   2.kibibytes # => 2048
  def kibibytes
    self * KIBIBYTE
  end
  alias :kibibyte :kibibytes

  # Returns the number of bytes equivalent to the megabytes provided.
  #
  #   2.megabytes # => 2_000_000
  def megabytes
    self * MEGABYTE
  end
  alias :megabyte :megabytes

  # Returns the number of bytes equivalent to the mebibytes provided.
  #
  #   2.mebibytes # => 2_097_152
  def mebibytes
    self * MEBIBYTE
  end
  alias :mebibyte :mebibytes

  # Returns the number of bytes equivalent to the gigabytes provided.
  #
  #   2.gigabytes # => 2_000_000_000
  def gigabytes
    self * GIGABYTE
  end
  alias :gigabyte :gigabytes

  # Returns the number of bytes equivalent to the gibibytes provided.
  #
  #   2.gibibytes # => 2_147_483_648
  def gibibytes
    self * GIBIBYTE
  end
  alias :gibibyte :gibibytes

  # Returns the number of bytes equivalent to the terabytes provided.
  #
  #   2.terabytes # => 2_000_000_000_000
  def terabytes
    self * TERABYTE
  end
  alias :terabyte :terabytes

  # Returns the number of bytes equivalent to the tebibytes provided.
  #
  #   2.tebibytes # => 2_199_023_255_552
  def tebibytes
    self * TEBIBYTE
  end
  alias :tebibyte :tebibytes

  # Returns the number of bytes equivalent to the petabytes provided.
  #
  #   2.petabytes # => 2_000_000_000_000_000
  def petabytes
    self * PETABYTE
  end
  alias :petabyte :petabytes

  # Returns the number of bytes equivalent to the pebibytes provided.
  #
  #   2.pebibytes # => 2_251_799_813_685_248
  def pebibytes
    self * PEBIBYTE
  end
  alias :pebibyte :pebibytes

  # Returns the number of bytes equivalent to the exabytes provided.
  #
  #   2.exabytes # => 2_000_000_000_000_000_000
  def exabytes
    self * EXABYTE
  end
  alias :exabyte :exabytes

  # Returns the number of bytes equivalent to the exbibytes provided.
  #
  #   2.exbibytes # => 2_305_843_009_213_693_952
  def exbibytes
    self * EXBIBYTE
  end
  alias :exbibyte :exbibytes

  # Returns the number of bytes equivalent to the zettabytes provided.
  #
  #   2.zettabytes # => 2_000_000_000_000_000_000_000
  def zettabytes
    self * ZETTABYTE
  end
  alias :zettabyte :zettabytes

  # Returns the number of bytes equivalent to the zebibytes provided.
  #
  #   2.zebibytes # => 2_361_183_241_434_822_606_848
  def zebibytes
    self * ZEBIBYTE
  end
  alias :zebibyte :zebibytes

  # Returns the number of bytes equivalent to the yottabytes provided.
  #
  #   2.yottabytes # => 2_000_000_000_000_000_000_000_000
  def yottabytes
    self * YOTTABYTE
  end
  alias :yottabyte :yottabytes

  # Returns the number of bytes equivalent to the yobibytes provided.
  #
  #   2.yobibytes # => 2_417_851_639_229_258_349_412_352
  def yobibytes
    self * YOBIBYTE
  end
  alias :yobibyte :yobibytes
end

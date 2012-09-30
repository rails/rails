class Numeric
  KIBIBYTE = 1024
  MEBIBYTE = KIBIBYTE * 1024
  GIBIBYTE = MEBIBYTE * 1024
  TEBIBYTE = GIBIBYTE * 1024
  PEBIBYTE = TEBIBYTE * 1024
  EXBIBYTE  = PEBIBYTE * 1024

  # Enables the use of byte calculations and declarations, like 45.bytes + 2.6.mebibytes
  def bytes
    self
  end
  alias :byte :bytes

  def kibibytes
    self * KIBIBYTE
  end
  alias :kibibyte :kibibytes

  def mebibytes
    self * MEBIBYTE
  end
  alias :mebibyte :mebibytes

  def gibibytes
    self * GIBIBYTE
  end
  alias :gibibyte :gibibytes

  def tebibytes
    self * TEBIBYTE
  end
  alias :tebibyte :tebibytes

  def pebibytes
    self * PEBIBYTE
  end
  alias :pebibyte :pebibytes

  def exbibytes
    self * EXBIBYTE
  end
  alias :exbibyte :exbibytes
end

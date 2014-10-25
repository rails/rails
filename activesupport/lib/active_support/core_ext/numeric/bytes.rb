class Numeric
  # See http://physics.nist.gov/cuu/Units/prefixes.html for definition of SI prefixes
  KILOBYTE = 1000
  MEGABYTE = KILOBYTE * 1000
  GIGABYTE = MEGABYTE * 1000
  TERABYTE = GIGABYTE * 1000
  PETABYTE = TERABYTE * 1000
  EXABYTE  = PETABYTE * 1000

  # See http://physics.nist.gov/cuu/Units/binary.html for definition of binary prefixes
  KIBIBYTE = 1024
  MEBIBYTE = KIBIBYTE * 1024
  GIBIBYTE = MEBIBYTE * 1024
  TEBIBYTE = GIBIBYTE * 1024
  PEBIBYTE = TEBIBYTE * 1024
  EXBIBYTE = PEBIBYTE * 1024

  # Enables the use of byte calculations and declarations, like 45.bytes + 2.6.megabytes
  def bytes(opts={})
    self
  end
  alias :byte :bytes

  def kilobytes(opts={})
    self * (si_prefix?(opts) ? KILOBYTE : KIBIBYTE)
  end
  alias :kilobyte :kilobytes

  def megabytes(opts={})
    self * (si_prefix?(opts) ? MEGABYTE : MEBIBYTE)
  end
  alias :megabyte :megabytes

  def gigabytes(opts={})
    self * (si_prefix?(opts) ? GIGABYTE : GIBIBYTE)
  end
  alias :gigabyte :gigabytes

  def terabytes(opts={})
    self * (si_prefix?(opts) ? TERABYTE : TEBIBYTE)
  end
  alias :terabyte :terabytes

  def petabytes(opts={})
    self * (si_prefix?(opts) ? PETABYTE : PEBIBYTE)
  end
  alias :petabyte :petabytes

  def exabytes(opts={})
    self * (si_prefix?(opts) ? EXABYTE : EXBIBYTE)
  end
  alias :exabyte :exabytes

  private

    def si_prefix?(opts)
      case opts
      when Symbol
        opts == :si
      when Hash
        opts.symbolize_keys[:prefix] == :si
      else
        false
      end
    end
end

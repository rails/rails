# frozen_string_literal: true

class Numeric
  KILOBYTE = 1024
  MEGABYTE = KILOBYTE * 1024
  GIGABYTE = MEGABYTE * 1024
  TERABYTE = GIGABYTE * 1024
  PETABYTE = TERABYTE * 1024
  EXABYTE  = PETABYTE * 1024

  # Enables the use of byte calculations and declarations, like 45.bytes + 2.6.megabytes
  #
  #   2.bytes # => 2
  def bytes
    self
  end
  alias :byte :bytes

  # Returns the number of bytes equivalent to the kilobytes provided.
  #
  #   2.kilobytes # => 2 048
  def kilobytes
    self * KILOBYTE
  end
  alias :kilobyte :kilobytes

  # Returns the number of bytes equivalent to the megabytes provided.
  #
  #   2.megabytes # => 2 097 152
  def megabytes
    self * MEGABYTE
  end
  alias :megabyte :megabytes

  # Returns the number of bytes equivalent to the gigabytes provided.
  #
  #   2.gigabytes # => 2 147 483 648
  def gigabytes
    self * GIGABYTE
  end
  alias :gigabyte :gigabytes

  # Returns the number of bytes equivalent to the terabytes provided.
  #
  #   2.terabytes # => 2 199 023 255 552
  def terabytes
    self * TERABYTE
  end
  alias :terabyte :terabytes

  # Returns the number of bytes equivalent to the petabytes provided.
  #
  #   2.petabytes # => 2 251 799 813 685 248
  def petabytes
    self * PETABYTE
  end
  alias :petabyte :petabytes

  # Returns the number of bytes equivalent to the exabytes provided.
  #
  #   2.exabytes # => 2 305 843 009 213 693 952
  def exabytes
    self * EXABYTE
  end
  alias :exabyte :exabytes
end

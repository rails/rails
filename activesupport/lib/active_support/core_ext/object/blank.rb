# frozen_string_literal: true

require "concurrent/map"

class Object
  # An object is blank if it's false, empty, or a whitespace string.
  # For example, +nil+, '', '   ', [], {}, and +false+ are all blank.
  #
  # This simplifies
  #
  #   !address || address.empty?
  #
  # to
  #
  #   address.blank?
  #
  #: () -> bool
  def blank?
    respond_to?(:empty?) ? !!empty? : false
  end

  # An object is present if it's not blank.
  #
  #: () -> bool
  def present?
    !blank?
  end

  # Returns the receiver if it's present otherwise returns +nil+.
  # <tt>object.presence</tt> is equivalent to
  #
  #    object.present? ? object : nil
  #
  # For example, something like
  #
  #   state   = params[:state]   if params[:state].present?
  #   country = params[:country] if params[:country].present?
  #   region  = state || country || 'US'
  #
  # becomes
  #
  #   region = params[:state].presence || params[:country].presence || 'US'
  #
  #: () -> self?
  def presence
    self if present?
  end
end

class NilClass
  # +nil+ is blank:
  #
  #   nil.blank? # => true
  #
  #: () -> true
  def blank?
    true
  end

  #: () -> false
  def present? # :nodoc:
    false
  end
end

class FalseClass
  # +false+ is blank:
  #
  #   false.blank? # => true
  #
  #: () -> true
  def blank?
    true
  end

  #: () -> false
  def present? # :nodoc:
    false
  end
end

class TrueClass
  # +true+ is not blank:
  #
  #   true.blank? # => false
  #
  #: () -> false
  def blank?
    false
  end

  #: () -> true
  def present? # :nodoc:
    true
  end
end

class Array
  # An array is blank if it's empty:
  #
  #   [].blank?      # => true
  #   [1,2,3].blank? # => false
  #
  #: () -> bool
  alias_method :blank?, :empty?

  #: () -> bool
  def present? # :nodoc:
    !empty?
  end
end

class Hash
  # A hash is blank if it's empty:
  #
  #   {}.blank?                # => true
  #   { key: 'value' }.blank?  # => false
  #
  #: () -> bool
  alias_method :blank?, :empty?

  #: () -> bool
  def present? # :nodoc:
    !empty?
  end
end

class Symbol
  # A Symbol is blank if it's empty:
  #
  #   :''.blank?     # => true
  #   :symbol.blank? # => false
  #
  #: () -> bool
  alias_method :blank?, :empty?

  #: () -> bool
  def present? # :nodoc:
    !empty?
  end
end

class String
  BLANK_RE = /\A[[:space:]]*\z/
  ENCODED_BLANKS = Concurrent::Map.new do |h, enc|
    h[enc] = Regexp.new(BLANK_RE.source.encode(enc), BLANK_RE.options | Regexp::FIXEDENCODING)
  end

  # A string is blank if it's empty or contains whitespaces only:
  #
  #   ''.blank?       # => true
  #   '   '.blank?    # => true
  #   "\t\n\r".blank? # => true
  #   ' blah '.blank? # => false
  #
  # Unicode whitespace is supported:
  #
  #   "\u00a0".blank? # => true
  #
  #: () -> bool
  def blank?
    # The regexp that matches blank strings is expensive. For the case of empty
    # strings we can speed up this method (~3.5x) with an empty? call. The
    # penalty for the rest of strings is marginal.
    empty? ||
      begin
        BLANK_RE.match?(self)
      rescue Encoding::CompatibilityError
        ENCODED_BLANKS[self.encoding].match?(self)
      end
  end

  #: () -> bool
  def present? # :nodoc:
    !blank?
  end
end

class Numeric # :nodoc:
  # No number is blank:
  #
  #   1.blank? # => false
  #   0.blank? # => false
  #
  #: () -> false
  def blank?
    false
  end

  #: () -> true
  def present?
    true
  end
end

class Time # :nodoc:
  # No Time is blank:
  #
  #   Time.now.blank? # => false
  #
  #: () -> false
  def blank?
    false
  end

  #: () -> true
  def present?
    true
  end
end

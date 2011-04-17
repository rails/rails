class Object
  # An object is blank if it's false, empty, or a whitespace string.
  # For example, "", "   ", +nil+, [], and {} are blank.
  #
  # This simplifies:
  #
  #   if !address.nil? && !address.empty?
  #
  # ...to:
  #
  #   if !address.blank?
  def blank?
    respond_to?(:empty?) ? empty? : !self
  end

  # An object is present if it's not <tt>blank?</tt>.
  def present?
    !blank?
  end

  # Returns object if it's #present? otherwise returns nil.
  # object.presence is equivalent to object.present? ? object : nil.
  #
  # This is handy for any representation of objects where blank is the same
  # as not present at all.  For example, this simplifies a common check for
  # HTTP POST/query parameters:
  #
  #   state   = params[:state]   if params[:state].present?
  #   country = params[:country] if params[:country].present?
  #   region  = state || country || 'US'
  #
  # ...becomes:
  #
  #   region = params[:state].presence || params[:country].presence || 'US'
  def presence
    self if present?
  end
end

class NilClass
  # Instances of NilClass are always blank
  #
  # === Example
  #
  # nil.blank? # => true
  def blank?
    true
  end
end

class FalseClass
  # Instances of FalseClass are always blank
  #
  # === Example
  #
  # false.blank? # => true
  def blank?
    true
  end
end

class TrueClass
  # Instances of TrueClass are never blank
  #
  # === Example
  #
  # true.blank? # => false
  def blank?
    false
  end
end

class Array
  # An array is blank if it's empty
  #
  # === Examples
  #
  # [].blank?      # => true
  # [1,2,3].blank? # => false
  alias_method :blank?, :empty?
end

class Hash
  # A hash is blank if it's empty
  #
  # === Examples
  #
  # {}.blank?                # => true
  # {:key => 'value'}.blank? # => false
  alias_method :blank?, :empty?
end

class String
  # A string is blank if it's empty or contains whitespaces only
  #
  # === Examples
  #
  # "".blank?                 # => true
  # "   ".blank?              # => true
  # " something here ".blank? # => false
  def blank?
    self !~ /\S/
  end
end

class Numeric #:nodoc:
  def blank?
    false
  end
end

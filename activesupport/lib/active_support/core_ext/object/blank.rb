# encoding: utf-8
require 'active_support/core_ext/string/encoding'

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

  # An object is present if it's not blank.
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

class NilClass #:nodoc:
  def blank?
    true
  end
end

class FalseClass #:nodoc:
  def blank?
    true
  end
end

class TrueClass #:nodoc:
  def blank?
    false
  end
end

class Array #:nodoc:
  alias_method :blank?, :empty?
end

class Hash #:nodoc:
  alias_method :blank?, :empty?
end

class String
  # 0x3000: fullwidth whitespace
  NON_WHITESPACE_REGEXP = %r![^\s#{[0x3000].pack("U")}]!

  # A string is blank if it's empty or contains whitespaces only:
  #
  #   "".blank?                 # => true
  #   "   ".blank?              # => true
  #   "　".blank?               # => true
  #   " something here ".blank? # => false
  #
  def blank?
    return true if empty?

    # 1.8 does not takes [:space:] properly
    if encoding_aware?
      self =~ /\A[[:space:]]*\z/
    else
      self !~ NON_WHITESPACE_REGEXP
    end
  end
end

class Numeric #:nodoc:
  def blank?
    false
  end
end

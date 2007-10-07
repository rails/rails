begin
  # See http://bogomips.org/fast_xs/ by Eric Wong
  require 'fast_xs'

  class String
    alias_method :original_xs, :to_xs if method_defined?(:to_xs)
    alias_method :to_xs, :fast_xs
  end
rescue LoadError
  # fast_xs extension unavailable.
end

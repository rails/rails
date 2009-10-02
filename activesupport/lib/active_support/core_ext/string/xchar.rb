begin
  # See http://bogomips.org/fast_xs/ by Eric Wong.
  # Also included with hpricot.
  require 'fast_xs'
rescue LoadError
  # fast_xs extension unavailable
else
  begin
    require 'builder'
  rescue LoadError
    # builder demands the first shot at defining String#to_xs
  end

  class String
    alias_method :original_xs, :to_xs if method_defined?(:to_xs)
    alias_method :to_xs, :fast_xs
  end
end

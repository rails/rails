begin
  # See http://fast-xs.rubyforge.org/ by Eric Wong.
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

    # to_xs expects 0 args from Builder < 3 but not >= 3, although fast_xs is 0 args
    if instance_method(:to_xs).arity == 0
      alias_method :to_xs, :fast_xs
    else
      def fast_xs_absorb_args(*args); fast_xs; end
      alias_method :to_xs, :fast_xs_absorb_args
    end
  end
end

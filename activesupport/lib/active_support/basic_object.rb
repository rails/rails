# A base class with no predefined methods that tries to behave like Builder's
# BlankSlate in Ruby 1.9. In Ruby pre-1.9, this is actually the
# Builder::BlankSlate class.
#
# Ruby 1.9 introduces BasicObject which differs slightly from Builder's
# BlankSlate that has been used so far. ActiveSupport::BasicObject provides a
# barebones base class that emulates Builder::BlankSlate while still relying on
# Ruby 1.9's BasicObject in Ruby 1.9.
module ActiveSupport
  if RUBY_VERSION >= '1.9'
    class BasicObject < ::BasicObject
      undef_method :==
      undef_method :equal?

      # Let ActiveSupport::BasicObject at least raise exceptions.
      def raise(*args)
        ::Object.send(:raise, *args)
      end
    end
  else
    require 'blankslate'
    BasicObject = BlankSlate
  end
end

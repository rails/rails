# Ruby 1.9 introduces BasicObject which differs slighly from Builder's BlankSlate
# that had been used so far ActiveSupport::BasicObject provides a barebones object with
# the same method on both versions.
module ActiveSupport
  if RUBY_VERSION >= '1.9'
    class BasicObject < ::BasicObject
      undef_method :==
      undef_method :equal?
    end
  else
    require 'blankslate'
    BasicObject = BlankSlate
  end
end

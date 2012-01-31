require 'active_support/deprecation'

# Extensions to +nil+ which allow for more helpful error messages for people who
# are new to Rails.
#
# NilClass#id exists in Ruby 1.8 (though it is deprecated). Since +id+ is a fundamental
# method of Active Record models NilClass#id is redefined as well to raise a RuntimeError
# and warn the user. She probably wanted a model database identifier and the 4
# returned by the original method could result in obscure bugs.
#
# The flag <tt>config.whiny_nils</tt> determines whether this feature is enabled.
# By default it is on in development and test modes, and it is off in production
# mode.
class NilClass
  def self.add_whiner(klass)
    ActiveSupport::Deprecation.warn "NilClass.add_whiner is deprecated and this functionality is " \
      "removed from Rails versions as it affects Ruby 1.9 performance.", caller
  end

  # Raises a RuntimeError when you attempt to call +id+ on +nil+.
  def id
    raise RuntimeError, "Called id for nil, which would mistakenly be #{object_id} -- if you really wanted the id of nil, use object_id", caller
  end
end

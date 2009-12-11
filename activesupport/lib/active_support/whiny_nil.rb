# Extensions to +nil+ which allow for more helpful error messages for people who
# are new to Rails.
#
# Ruby raises NoMethodError if you invoke a method on an object that does not
# respond to it:
#
#   $ ruby -e nil.destroy
#   -e:1: undefined method `destroy' for nil:NilClass (NoMethodError)
#
# With these extensions, if the method belongs to the public interface of the
# classes in NilClass::WHINERS the error message suggests which could be the
# actual intended class:
#
#   $ script/runner nil.destroy 
#   ...
#   You might have expected an instance of ActiveRecord::Base.
#   ...
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
  WHINERS = [::Array]
  WHINERS << ::ActiveRecord::Base if defined? ::ActiveRecord

  METHOD_CLASS_MAP = Hash.new

  WHINERS.each do |klass|
    methods = klass.public_instance_methods - public_instance_methods
    class_name = klass.name
    methods.each { |method| METHOD_CLASS_MAP[method.to_sym] = class_name }
  end

  # Raises a RuntimeError when you attempt to call +id+ on +nil+.
  def id
    raise RuntimeError, "Called id for nil, which would mistakenly be 4 -- if you really wanted the id of nil, use object_id", caller
  end

  private
    def method_missing(method, *args, &block)
      # Ruby 1.9.2: disallow explicit coercion via method_missing.
      if method == :to_ary || method == :to_str
        raise NoMethodError, "undefined method `#{method}' for nil:NilClass"
      elsif klass = METHOD_CLASS_MAP[method]
        raise_nil_warning_for klass, method, caller
      else
        super
      end
    end

    # Raises a NoMethodError when you attempt to call a method on +nil+.
    def raise_nil_warning_for(class_name = nil, selector = nil, with_caller = nil)
      message = "You have a nil object when you didn't expect it!"
      message << "\nYou might have expected an instance of #{class_name}." if class_name
      message << "\nThe error occurred while evaluating nil.#{selector}" if selector

      raise NoMethodError, message, with_caller || caller
    end
end

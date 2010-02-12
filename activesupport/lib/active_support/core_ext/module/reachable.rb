require 'active_support/core_ext/module/anonymous'
require 'active_support/core_ext/string/inflections'

class Module
  def reachable? #:nodoc:
    !anonymous? && name.constantize.equal?(self)
  rescue NameError
    false
  end
end

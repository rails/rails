#!/usr/bin/env ruby
#--
# Copyright 2004 by Jim Weirich (jim@weirichhouse.org).
# All rights reserved.

# Permission is granted for use, copying, modification, distribution,
# and distribution of modified versions of this work as long as the
# above copyright notice is included.
#++

module Builder #:nodoc:

  # BlankSlate provides an abstract base class with no predefined
  # methods (except for <tt>\_\_send__</tt> and <tt>\_\_id__</tt>).
  # BlankSlate is useful as a base class when writing classes that
  # depend upon <tt>method_missing</tt> (e.g. dynamic proxies).
  class BlankSlate
    class << self

      # Hide the method named +name+ in the BlankSlate class.  Don't
      # hide +instance_eval+ or any method beginning with "__".
      def hide(name)
	undef_method name if
	  instance_methods.include?(name.to_s) and
	  name !~ /^(__|instance_eval)/
      end
    end

    instance_methods.each { |m| hide(m) }
  end
end

# Since Ruby is very dynamic, methods added to the ancestors of
# BlankSlate <em>after BlankSlate is defined</em> will show up in the
# list of available BlankSlate methods.  We handle this by defining a
# hook in the Object and Kernel classes that will hide any defined
module Kernel #:nodoc:
  class << self
    alias_method :blank_slate_method_added, :method_added

    # Detect method additions to Kernel and remove them in the
    # BlankSlate class.
    def method_added(name)
      blank_slate_method_added(name)
      return if self != Kernel
      Builder::BlankSlate.hide(name)
    end
  end
end

class Object
  class << self
    alias_method :blank_slate_method_added, :method_added

    # Detect method additions to Object and remove them in the
    # BlankSlate class.
    def method_added(name) #:nodoc:
      blank_slate_method_added(name)
      return if self != Object
      Builder::BlankSlate.hide(name)
    end
  end
end

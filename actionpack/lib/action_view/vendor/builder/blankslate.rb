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
  class BlankSlate #:nodoc:
    instance_methods.each { |m| undef_method m unless m =~ /^(__|instance_eval)/ }
  end

end

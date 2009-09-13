#!/usr/bin/env ruby
#--
# Copyright 2004, 2006 by Jim Weirich (jim@weirichhouse.org).
# All rights reserved.

# Permission is granted for use, copying, modification, distribution,
# and distribution of modified versions of this work as long as the
# above copyright notice is included.
#++

require 'blankslate'

######################################################################
# BlankSlate has been promoted to a top level name and is now
# available as a standalone gem.  We make the name available in the
# Builder namespace for compatibility.
#
module Builder
  BlankSlate = ::BlankSlate
end

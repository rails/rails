# This is private interface.
#
# Rails components cherry pick from Active Support as needed, but there are a
# few features that are used for sure some way or another and it is not worth
# to put individual requires absolutely everywhere. Think blank? for example.
#
# This file is loaded by every Rails component except Active Support itself,
# but it does not belong to the Rails public interface. It is internal to
# Rails and can change anytime.

# blank? and present?
require 'active_support/core_ext/object/blank'

# in?
require 'active_support/core_ext/object/inclusion'

# Rails own autoload, eager_load, etc.
require 'active_support/dependencies/autoload'

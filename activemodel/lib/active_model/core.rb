# This file is required by each major ActiveModel component for the core requirements.  This allows you to
# load individual pieces of ActiveModel as needed.
$LOAD_PATH << File.join(File.dirname(__FILE__), '..', '..', '..', 'activesupport', 'lib')

# premature optimization?
# So far, we only need the string inflections and not the rest of ActiveSupport.
require 'active_support/inflector'
# in case active_support/inflector is required without the rest of active_support
Requirer.new(__FILE__).require_all
require 'active_support/inflections'
require 'active_support/core_ext/string/inflections'

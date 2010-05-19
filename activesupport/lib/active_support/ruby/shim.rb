# Backported Ruby builtins so you can code with the latest & greatest
# but still run on any Ruby 1.8.x.
#
# Date        next_year, next_month
# DateTime    to_date, to_datetime, xmlschema
# Enumerable  group_by, each_with_object, none?
# Process     Process.daemon
# REXML       security fix
# String      ord
# Time        to_date, to_time, to_datetime
require 'active_support'
require 'active_support/core_ext/date/calculations'
require 'active_support/core_ext/date_time/conversions'
require 'active_support/core_ext/enumerable'
require 'active_support/core_ext/process/daemon'
require 'active_support/core_ext/string/conversions'
require 'active_support/core_ext/string/interpolation'
require 'active_support/core_ext/string/encoding'
require 'active_support/core_ext/rexml'
require 'active_support/core_ext/time/conversions'
require 'active_support/core_ext/file/path'
require 'active_support/core_ext/module/method_names'
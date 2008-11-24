#--
# Copyright (c) 2005 David Heinemeier Hansson
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#++

module ActiveSupport
  autoload :Duration, 'active_support/duration'
  autoload :Gzip, 'active_support/gzip'
  autoload :MessageVerifier, 'active_support/message_verifier'
  autoload :OptionMerger, 'active_support/option_merger'
  autoload :OrderedHash, 'active_support/ordered_hash'
  autoload :OrderedOptions, 'active_support/ordered_options'
  autoload :SecureRandom, 'active_support/secure_random'
  autoload :StringInquirer, 'active_support/string_inquirer'
  autoload :TimeWithZone, 'active_support/time_with_zone'
  autoload :TimeZone, 'active_support/values/time_zone'
end

require 'active_support/vendor'
require 'active_support/basic_object'
require 'active_support/inflector'
require 'active_support/callbacks'

require 'active_support/core_ext'

require 'active_support/buffered_logger'
require 'active_support/backtrace_cleaner'

require 'active_support/cache'

require 'active_support/dependencies'
require 'active_support/deprecation'

require 'active_support/memoizable'

require 'active_support/json'

require 'active_support/multibyte'

require 'active_support/base64'

require 'active_support/rescuable'

I18n.load_path << "#{File.dirname(__FILE__)}/active_support/locale/en.yml"

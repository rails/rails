=begin rdoc

= Scanner for TMail

=end
#--
# Copyright (c) 1998-2003 Minero Aoki <aamine@loveruby.net>
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
#
# Note: Originally licensed under LGPL v2+. Using MIT license for Rails
# with permission of Minero Aoki.
#++
#:stopdoc:
#require 'tmail/require_arch'
require 'tmail/utils'
require 'tmail/config'

module TMail
  # NOTE: It woiuld be nice if these two libs could boith be called "tmailscanner", and
  # the native extension would have precedence. However RubyGems boffs that up b/c
  # it does not gaurantee load_path order.
  begin
    raise LoadError, 'Turned off native extentions by user choice' if ENV['NORUBYEXT']
    require('tmail/tmailscanner') # c extension
    Scanner = TMailScanner
  rescue LoadError
    require 'tmail/scanner_r'
    Scanner = TMailScanner
  end
end
#:stopdoc:
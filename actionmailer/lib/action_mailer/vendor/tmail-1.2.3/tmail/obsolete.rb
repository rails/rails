=begin rdoc

= Obsolete methods that are deprecated

If you really want to see them, go to lib/tmail/obsolete.rb and view to your
heart's content.

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
module TMail #:nodoc:

  class Mail
    alias include? key?
    alias has_key? key?

    def values
      ret = []
      each_field {|v| ret.push v }
      ret
    end

    def value?( val )
      HeaderField === val or return false

      [ @header[val.name.downcase] ].flatten.include? val
    end

    alias has_value? value?
  end

  class Mail
    def from_addr( default = nil )
      addr, = from_addrs(nil)
      addr || default
    end

    def from_address( default = nil )
      if a = from_addr(nil)
        a.spec
      else
        default
      end
    end

    alias from_address= from_addrs=

    def from_phrase( default = nil )
      if a = from_addr(nil)
        a.phrase
      else
        default
      end
    end

    alias msgid  message_id
    alias msgid= message_id=

    alias each_dest each_destination
  end

  class Address
    alias route routes
    alias addr spec

    def spec=( str ) 
      @local, @domain = str.split(/@/,2).map {|s| s.split(/\./) }
    end

    alias addr= spec=
    alias address= spec=
  end

  class MhMailbox
    alias new_mail new_port
    alias each_mail each_port
    alias each_newmail each_new_port
  end
  class UNIXMbox
    alias new_mail new_port
    alias each_mail each_port
    alias each_newmail each_new_port
  end
  class Maildir
    alias new_mail new_port
    alias each_mail each_port
    alias each_newmail each_new_port
  end

  extend TextUtils

  class << self
    alias msgid?    message_id?
    alias boundary  new_boundary
    alias msgid     new_message_id
    alias new_msgid new_message_id
  end

  def Mail.boundary
    ::TMail.new_boundary
  end

  def Mail.msgid
    ::TMail.new_message_id
  end

end   # module TMail
#:startdoc:
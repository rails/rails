#
# base64.rb
#
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

module TMail

  module Base64

    module_function

    def rb_folding_encode( str, eol = "\n", limit = 60 )
      [str].pack('m')
    end

    def rb_encode( str )
      [str].pack('m').tr( "\r\n", '' )
    end

    def rb_decode( str, strict = false )
      str.unpack('m')
    end

    begin
      require 'tmail/base64.so'
      alias folding_encode c_folding_encode
      alias encode         c_encode
      alias decode         c_decode
      class << self
        alias folding_encode c_folding_encode
        alias encode         c_encode
        alias decode         c_decode
      end
    rescue LoadError
      alias folding_encode rb_folding_encode
      alias encode         rb_encode
      alias decode         rb_decode
      class << self
        alias folding_encode rb_folding_encode
        alias encode         rb_encode
        alias decode         rb_decode
      end
    end

  end

end

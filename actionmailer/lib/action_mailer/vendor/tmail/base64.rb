#
# base64.rb
#
# Copyright (c) 1998-2003 Minero Aoki <aamine@loveruby.net>
#
# This program is free software.
# You can distribute/modify this program under the terms of
# the GNU Lesser General Public License version 2 or later.
#

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

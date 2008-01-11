=begin rdoc

= Configuration Class

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

module TMail

  class Config

    def initialize( strict )
      @strict_parse = strict
      @strict_base64decode = strict
    end

    def strict_parse?
      @strict_parse
    end

    attr_writer :strict_parse

    def strict_base64decode?
      @strict_base64decode
    end

    attr_writer :strict_base64decode

    def new_body_port( mail )
      StringPort.new
    end

    alias new_preamble_port  new_body_port
    alias new_part_port      new_body_port
  
  end

  DEFAULT_CONFIG        = Config.new(false)
  DEFAULT_STRICT_CONFIG = Config.new(true)

  def Config.to_config( arg )
    return DEFAULT_STRICT_CONFIG if arg == true
    return DEFAULT_CONFIG        if arg == false
    arg or DEFAULT_CONFIG
  end

end

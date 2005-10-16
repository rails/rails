#
# encode.rb
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

require 'nkf'
require 'tmail/base64.rb'
require 'tmail/stringio'
require 'tmail/utils'


module TMail

  module StrategyInterface

    def create_dest( obj )
      case obj
      when nil
        StringOutput.new
      when String
        StringOutput.new(obj)
      when IO, StringOutput
        obj
      else
        raise TypeError, 'cannot handle this type of object for dest'
      end
    end
    module_function :create_dest

    def encoded( eol = "\r\n", charset = 'j', dest = nil )
      accept_strategy Encoder, eol, charset, dest
    end

    def decoded( eol = "\n", charset = 'e', dest = nil )
      accept_strategy Decoder, eol, charset, dest
    end

    alias to_s decoded
  
    def accept_strategy( klass, eol, charset, dest = nil )
      dest ||= ''
      accept klass.new(create_dest(dest), charset, eol)
      dest
    end

  end


  ###
  ### MIME B encoding decoder
  ###

  class Decoder

    include TextUtils

    encoded = '=\?(?:iso-2022-jp|euc-jp|shift_jis)\?[QB]\?[a-z0-9+/=]+\?='
    ENCODED_WORDS = /#{encoded}(?:\s+#{encoded})*/i

    OUTPUT_ENCODING = {
      'EUC'  => 'e',
      'SJIS' => 's',
    }

    def self.decode( str, encoding = nil )
      encoding ||= (OUTPUT_ENCODING[$KCODE] || 'j')
      opt = '-m' + encoding
      str.gsub(ENCODED_WORDS) {|s| NKF.nkf(opt, s) }
    end

    def initialize( dest, encoding = nil, eol = "\n" )
      @f = StrategyInterface.create_dest(dest)
      @encoding = (/\A[ejs]/ === encoding) ? encoding[0,1] : nil
      @eol = eol
    end

    def decode( str )
      self.class.decode(str, @encoding)
    end
    private :decode

    def terminate
    end

    def header_line( str )
      @f << decode(str)
    end

    def header_name( nm )
      @f << nm << ': '
    end

    def header_body( str )
      @f << decode(str)
    end
      
    def space
      @f << ' '
    end

    alias spc space

    def lwsp( str )
      @f << str
    end
      
    def meta( str )
      @f << str
    end

    def text( str )
      @f << decode(str)
    end

    def phrase( str )
      @f << quote_phrase(decode(str))
    end

    def kv_pair( k, v )
      @f << k << '=' << v
    end

    def puts( str = nil )
      @f << str if str
      @f << @eol
    end

    def write( str )
      @f << str
    end

  end


  ###
  ### MIME B-encoding encoder
  ###

  #
  # FIXME: This class can handle only (euc-jp/shift_jis -> iso-2022-jp).
  #
  class Encoder

    include TextUtils

    BENCODE_DEBUG = false unless defined?(BENCODE_DEBUG)

    def Encoder.encode( str )
      e = new()
      e.header_body str
      e.terminate
      e.dest.string
    end

    SPACER       = "\t"
    MAX_LINE_LEN = 70

    OPTIONS = {
      'EUC'  => '-Ej -m0',
      'SJIS' => '-Sj -m0',
      'UTF8' => nil,      # FIXME
      'NONE' => nil
    }

    def initialize( dest = nil, encoding = nil, eol = "\r\n", limit = nil )
      @f = StrategyInterface.create_dest(dest)
      @opt = OPTIONS[$KCODE]
      @eol = eol
      reset
    end

    def normalize_encoding( str )
      if @opt
      then NKF.nkf(@opt, str)
      else str
      end
    end

    def reset
      @text = ''
      @lwsp = ''
      @curlen = 0
    end

    def terminate
      add_lwsp ''
      reset
    end

    def dest
      @f
    end

    def puts( str = nil )
      @f << str if str
      @f << @eol
    end

    def write( str )
      @f << str
    end

    #
    # add
    #

    def header_line( line )
      scanadd line
    end

    def header_name( name )
      add_text name.split(/-/).map {|i| i.capitalize }.join('-')
      add_text ':'
      add_lwsp ' '
    end

    def header_body( str )
      scanadd normalize_encoding(str)
    end

    def space
      add_lwsp ' '
    end

    alias spc space

    def lwsp( str )
      add_lwsp str.sub(/[\r\n]+[^\r\n]*\z/, '')
    end

    def meta( str )
      add_text str
    end

    def text( str )
      scanadd normalize_encoding(str)
    end

    def phrase( str )
      str = normalize_encoding(str)
      if CONTROL_CHAR === str
        scanadd str
      else
        add_text quote_phrase(str)
      end
    end

    # FIXME: implement line folding
    #
    def kv_pair( k, v )
      return if v.nil?
      v = normalize_encoding(v)
      if token_safe?(v)
        add_text k + '=' + v
      elsif not CONTROL_CHAR === v
        add_text k + '=' + quote_token(v)
      else
        # apply RFC2231 encoding
        kv = k + '*=' + "iso-2022-jp'ja'" + encode_value(v)
        add_text kv
      end
    end

    def encode_value( str )
      str.gsub(TOKEN_UNSAFE) {|s| '%%%02x' % s[0] }
    end

    private

    def scanadd( str, force = false )
      types = ''
      strs = []

      until str.empty?
        if m = /\A[^\e\t\r\n ]+/.match(str)
          types << (force ? 'j' : 'a')
          strs.push m[0]

        elsif m = /\A[\t\r\n ]+/.match(str)
          types << 's'
          strs.push m[0]

        elsif m = /\A\e../.match(str)
          esc = m[0]
          str = m.post_match
          if esc != "\e(B" and m = /\A[^\e]+/.match(str)
            types << 'j'
            strs.push m[0]
          end

        else
          raise 'TMail FATAL: encoder scan fail'
        end
        (str = m.post_match) unless m.nil?
      end

      do_encode types, strs
    end

    def do_encode( types, strs )
      #
      # result  : (A|E)(S(A|E))*
      # E       : W(SW)*
      # W       : (J|A)+ but must contain J  # (J|A)*J(J|A)*
      # A       : <<A character string not to be encoded>>
      # J       : <<A character string to be encoded>>
      # S       : <<LWSP>>
      #
      # An encoding unit is `E'.
      # Input (parameter `types') is  (J|A)(J|A|S)*(J|A)
      #
      if BENCODE_DEBUG
        puts
        puts '-- do_encode ------------'
        puts types.split(//).join(' ')
        p strs
      end

      e = /[ja]*j[ja]*(?:s[ja]*j[ja]*)*/

      while m = e.match(types)
        pre = m.pre_match
        concat_A_S pre, strs[0, pre.size] unless pre.empty?
        concat_E m[0], strs[m.begin(0) ... m.end(0)]
        types = m.post_match
        strs.slice! 0, m.end(0)
      end
      concat_A_S types, strs
    end

    def concat_A_S( types, strs )
      i = 0
      types.each_byte do |t|
        case t
        when ?a then add_text strs[i]
        when ?s then add_lwsp strs[i]
        else
          raise "TMail FATAL: unknown flag: #{t.chr}"
        end
        i += 1
      end
    end
    
    METHOD_ID = {
      ?j => :extract_J,
      ?e => :extract_E,
      ?a => :extract_A,
      ?s => :extract_S
    }

    def concat_E( types, strs )
      if BENCODE_DEBUG
        puts '---- concat_E'
        puts "types=#{types.split(//).join(' ')}"
        puts "strs =#{strs.inspect}"
      end

      flush() unless @text.empty?

      chunk = ''
      strs.each_with_index do |s,i|
        mid = METHOD_ID[types[i]]
        until s.empty?
          unless c = __send__(mid, chunk.size, s)
            add_with_encode chunk unless chunk.empty?
            flush
            chunk = ''
            fold
            c = __send__(mid, 0, s)
            raise 'TMail FATAL: extract fail' unless c
          end
          chunk << c
        end
      end
      add_with_encode chunk unless chunk.empty?
    end

    def extract_J( chunksize, str )
      size = max_bytes(chunksize, str.size) - 6
      size = (size % 2 == 0) ? (size) : (size - 1)
      return nil if size <= 0
      "\e$B#{str.slice!(0, size)}\e(B"
    end

    def extract_A( chunksize, str )
      size = max_bytes(chunksize, str.size)
      return nil if size <= 0
      str.slice!(0, size)
    end

    alias extract_S extract_A

    def max_bytes( chunksize, ssize )
      (restsize() - '=?iso-2022-jp?B??='.size) / 4 * 3 - chunksize
    end

    #
    # free length buffer
    #

    def add_text( str )
      @text << str
      # puts '---- text -------------------------------------'
      # puts "+ #{str.inspect}"
      # puts "txt >>>#{@text.inspect}<<<"
    end

    def add_with_encode( str )
      @text << "=?iso-2022-jp?B?#{Base64.encode(str)}?="
    end

    def add_lwsp( lwsp )
      # puts '---- lwsp -------------------------------------'
      # puts "+ #{lwsp.inspect}"
      fold if restsize() <= 0
      flush
      @lwsp = lwsp
    end

    def flush
      # puts '---- flush ----'
      # puts "spc >>>#{@lwsp.inspect}<<<"
      # puts "txt >>>#{@text.inspect}<<<"
      @f << @lwsp << @text
      @curlen += (@lwsp.size + @text.size)
      @text = ''
      @lwsp = ''
    end

    def fold
      # puts '---- fold ----'
      @f << @eol
      @curlen = 0
      @lwsp = SPACER
    end

    def restsize
      MAX_LINE_LEN - (@curlen + @lwsp.size + @text.size)
    end

  end

end    # module TMail

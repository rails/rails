# scanner_r.rb
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
#:stopdoc:
require 'tmail/config'

module TMail

  class TMailScanner

    Version = '1.2.3'
    Version.freeze

    MIME_HEADERS = {
      :CTYPE        => true,
      :CENCODING    => true,
      :CDISPOSITION => true
    }

    alnum      = 'a-zA-Z0-9'
    atomsyms   = %q[  _#!$%&`'*+-{|}~^/=?  ].strip
    tokensyms  = %q[  _#!$%&`'*+-{|}~^@.    ].strip
    atomchars  = alnum + Regexp.quote(atomsyms)
    tokenchars = alnum + Regexp.quote(tokensyms)
    iso2022str = '\e(?!\(B)..(?:[^\e]+|\e(?!\(B)..)*\e\(B'

    eucstr  = "(?:[\xa1-\xfe][\xa1-\xfe])+"
    sjisstr = "(?:[\x81-\x9f\xe0-\xef][\x40-\x7e\x80-\xfc])+"
    utf8str = "(?:[\xc0-\xdf][\x80-\xbf]|[\xe0-\xef][\x80-\xbf][\x80-\xbf])+"

    quoted_with_iso2022  = /\A(?:[^\\\e"]+|#{iso2022str})+/n
    domlit_with_iso2022  = /\A(?:[^\\\e\]]+|#{iso2022str})+/n
    comment_with_iso2022 = /\A(?:[^\\\e()]+|#{iso2022str})+/n

    quoted_without_iso2022  = /\A[^\\"]+/n
    domlit_without_iso2022  = /\A[^\\\]]+/n
    comment_without_iso2022 = /\A[^\\()]+/n

    PATTERN_TABLE = {}
    PATTERN_TABLE['EUC'] =
      [
        /\A(?:[#{atomchars}]+|#{iso2022str}|#{eucstr})+/n,
        /\A(?:[#{tokenchars}]+|#{iso2022str}|#{eucstr})+/n,
        quoted_with_iso2022,
        domlit_with_iso2022,
        comment_with_iso2022
      ]
    PATTERN_TABLE['SJIS'] =
      [
        /\A(?:[#{atomchars}]+|#{iso2022str}|#{sjisstr})+/n,
        /\A(?:[#{tokenchars}]+|#{iso2022str}|#{sjisstr})+/n,
        quoted_with_iso2022,
        domlit_with_iso2022,
        comment_with_iso2022
      ]
    PATTERN_TABLE['UTF8'] =
      [
        /\A(?:[#{atomchars}]+|#{utf8str})+/n,
        /\A(?:[#{tokenchars}]+|#{utf8str})+/n,
        quoted_without_iso2022,
        domlit_without_iso2022,
        comment_without_iso2022
      ]
    PATTERN_TABLE['NONE'] =
      [
        /\A[#{atomchars}]+/n,
        /\A[#{tokenchars}]+/n,
        quoted_without_iso2022,
        domlit_without_iso2022,
        comment_without_iso2022
      ]


    def initialize( str, scantype, comments )
      init_scanner str
      @comments = comments || []
      @debug    = false

      # fix scanner mode
      @received  = (scantype == :RECEIVED)
      @is_mime_header = MIME_HEADERS[scantype]

      atom, token, @quoted_re, @domlit_re, @comment_re = PATTERN_TABLE[TMail.KCODE]
      @word_re = (MIME_HEADERS[scantype] ? token : atom)
    end

    attr_accessor :debug

    def scan( &block )
      if @debug
        scan_main do |arr|
          s, v = arr
          printf "%7d %-10s %s\n",
                 rest_size(),
                 s.respond_to?(:id2name) ? s.id2name : s.inspect,
                 v.inspect
          yield arr
        end
      else
        scan_main(&block)
      end
    end

    private

    RECV_TOKEN = {
      'from' => :FROM,
      'by'   => :BY,
      'via'  => :VIA,
      'with' => :WITH,
      'id'   => :ID,
      'for'  => :FOR
    }

    def scan_main
      until eof?
        if skip(/\A[\n\r\t ]+/n)   # LWSP
          break if eof?
        end

        if s = readstr(@word_re)
          if @is_mime_header
            yield [:TOKEN, s]
          else
            # atom
            if /\A\d+\z/ === s
              yield [:DIGIT, s]
            elsif @received
              yield [RECV_TOKEN[s.downcase] || :ATOM, s]
            else
              yield [:ATOM, s]
            end
          end

        elsif skip(/\A"/)
          yield [:QUOTED, scan_quoted_word()]

        elsif skip(/\A\[/)
          yield [:DOMLIT, scan_domain_literal()]

        elsif skip(/\A\(/)
          @comments.push scan_comment()

        else
          c = readchar()
          yield [c, c]
        end
      end

      yield [false, '$']
    end

    def scan_quoted_word
      scan_qstr(@quoted_re, /\A"/, 'quoted-word')
    end

    def scan_domain_literal
      '[' + scan_qstr(@domlit_re, /\A\]/, 'domain-literal') + ']'
    end

    def scan_qstr( pattern, terminal, type )
      result = ''
      until eof?
        if    s = readstr(pattern) then result << s
        elsif skip(terminal)       then return result
        elsif skip(/\A\\/)         then result << readchar()
        else
          raise "TMail FATAL: not match in #{type}"
        end
      end
      scan_error! "found unterminated #{type}"
    end

    def scan_comment
      result = ''
      nest = 1
      content = @comment_re

      until eof?
        if s = readstr(content) then result << s
        elsif skip(/\A\)/)      then nest -= 1
                                     return result if nest == 0
                                     result << ')'
        elsif skip(/\A\(/)      then nest += 1
                                     result << '('
        elsif skip(/\A\\/)      then result << readchar()
        else
          raise 'TMail FATAL: not match in comment'
        end
      end
      scan_error! 'found unterminated comment'
    end

    # string scanner

    def init_scanner( str )
      @src = str
    end

    def eof?
      @src.empty?
    end

    def rest_size
      @src.size
    end

    def readstr( re )
      if m = re.match(@src)
        @src = m.post_match
        m[0]
      else
        nil
      end
    end

    def readchar
      readstr(/\A./)
    end

    def skip( re )
      if m = re.match(@src)
        @src = m.post_match
        true
      else
        false
      end
    end

    def scan_error!( msg )
      raise SyntaxError, msg
    end

  end

end   # module TMail
#:startdoc:
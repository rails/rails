# encoding: us-ascii
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

# = TMail - The EMail Swiss Army Knife for Ruby
#
# The TMail library provides you with a very complete way to handle and manipulate EMails
# from within your Ruby programs.
#
# Used as the backbone for email handling by the Ruby on Rails and Nitro web frameworks as
# well as a bunch of other Ruby apps including the Ruby-Talk mailing list to newsgroup email
# gateway, it is a proven and reliable email handler that won't let you down.
#
# Originally created by Minero Aoki, TMail has been recently picked up by Mikel Lindsaar and
# is being actively maintained.  Numerous backlogged bug fixes have been applied as well as
# Ruby 1.9 compatibility and a swath of documentation to boot.
#
# TMail allows you to treat an email totally as an object and allow you to get on with your
# own programming without having to worry about crafting the perfect email address validation
# parser, or assembling an email from all it's component parts.
#
# TMail handles the most complex part of the email - the header.  It generates and parses
# headers and provides you with instant access to their innards through simple and logically
# named accessor and setter methods.
#
# TMail also provides a wrapper to Net/SMTP as well as Unix Mailbox handling methods to
# directly read emails from your unix mailbox, parse them and use them.
#
# Following is the comprehensive list of methods to access TMail::Mail objects.  You can also
# check out TMail::Mail, TMail::Address and TMail::Headers for other lists.
module TMail

  # Provides an exception to throw on errors in Syntax within TMail's parsers
  class SyntaxError < StandardError; end

  # Provides a new email boundary to separate parts of the email.  This is a random
  # string based off the current time, so should be fairly unique.
  #
  # For Example:
  #
  #  TMail.new_boundary
  #  #=> "mimepart_47bf656968207_25a8fbb80114"
  #  TMail.new_boundary
  #  #=> "mimepart_47bf66051de4_25a8fbb80240"
  def TMail.new_boundary
    'mimepart_' + random_tag
  end

  # Provides a new email message ID.  You can use this to generate unique email message
  # id's for your email so you can track them.
  #
  # Optionally takes a fully qualified domain name (default to the current hostname
  # returned by Socket.gethostname) that will be appended to the message ID.
  #
  # For Example:
  #
  #  email.message_id = TMail.new_message_id
  #  #=> "<47bf66845380e_25a8fbb80332@baci.local.tmail>"
  #  email.to_s
  #  #=> "Message-Id: <47bf668b633f1_25a8fbb80475@baci.local.tmail>\n\n"
  #  email.message_id = TMail.new_message_id("lindsaar.net")
  #  #=> "<47bf668b633f1_25a8fbb80475@lindsaar.net.tmail>"
  #  email.to_s
  #  #=> "Message-Id: <47bf668b633f1_25a8fbb80475@lindsaar.net.tmail>\n\n"
  def TMail.new_message_id( fqdn = nil )
    fqdn ||= ::Socket.gethostname
    "<#{random_tag()}@#{fqdn}.tmail>"
  end

  #:stopdoc:
  def TMail.random_tag #:nodoc:
    @uniq += 1
    t = Time.now
    sprintf('%x%x_%x%x%d%x',
            t.to_i, t.tv_usec,
            $$, Thread.current.object_id, @uniq, rand(255))
  end
  private_class_method :random_tag

  @uniq = 0

  #:startdoc:

  # Text Utils provides a namespace to define TOKENs, ATOMs, PHRASEs and CONTROL characters that
  # are OK per RFC 2822.
  #
  # It also provides methods you can call to determine if a string is safe
  module TextUtils

    aspecial     = %Q|()<>[]:;.\\,"|
    tspecial     = %Q|()<>[];:\\,"/?=|
    lwsp         = %Q| \t\r\n|
    control      = %Q|\x00-\x1f\x7f-\xff|

    CONTROL_CHAR  = /[#{control}]/n
    ATOM_UNSAFE   = /[#{Regexp.quote aspecial}#{control}#{lwsp}]/n
    PHRASE_UNSAFE = /[#{Regexp.quote aspecial}#{control}]/n
    TOKEN_UNSAFE  = /[#{Regexp.quote tspecial}#{control}#{lwsp}]/n

    # Returns true if the string supplied is free from characters not allowed as an ATOM
    def atom_safe?( str )
      not ATOM_UNSAFE === str
    end

    # If the string supplied has ATOM unsafe characters in it, will return the string quoted
    # in double quotes, otherwise returns the string unmodified
    def quote_atom( str )
      (ATOM_UNSAFE === str) ? dquote(str) : str
    end

    # If the string supplied has PHRASE unsafe characters in it, will return the string quoted
    # in double quotes, otherwise returns the string unmodified
    def quote_phrase( str )
      (PHRASE_UNSAFE === str) ? dquote(str) : str
    end

    # Returns true if the string supplied is free from characters not allowed as a TOKEN
    def token_safe?( str )
      not TOKEN_UNSAFE === str
    end

    # If the string supplied has TOKEN unsafe characters in it, will return the string quoted
    # in double quotes, otherwise returns the string unmodified
    def quote_token( str )
      (TOKEN_UNSAFE === str) ? dquote(str) : str
    end

    # Wraps supplied string in double quotes unless it is already wrapped
    # Returns double quoted string
    def dquote( str ) #:nodoc:
      unless str =~ /^".*?"$/
        '"' + str.gsub(/["\\]/n) {|s| '\\' + s } + '"'
      else
        str
      end
    end
    private :dquote

    # Unwraps supplied string from inside double quotes
    # Returns unquoted string
    def unquote( str )
      str =~ /^"(.*?)"$/m ? $1 : str
    end

    # Provides a method to join a domain name by it's parts and also makes it
    # ATOM safe by quoting it as needed
    def join_domain( arr )
      arr.map {|i|
          if /\A\[.*\]\z/ === i
            i
          else
            quote_atom(i)
          end
      }.join('.')
    end

    #:stopdoc:
    ZONESTR_TABLE = {
      'jst' =>   9 * 60,
      'eet' =>   2 * 60,
      'bst' =>   1 * 60,
      'met' =>   1 * 60,
      'gmt' =>   0,
      'utc' =>   0,
      'ut'  =>   0,
      'nst' => -(3 * 60 + 30),
      'ast' =>  -4 * 60,
      'edt' =>  -4 * 60,
      'est' =>  -5 * 60,
      'cdt' =>  -5 * 60,
      'cst' =>  -6 * 60,
      'mdt' =>  -6 * 60,
      'mst' =>  -7 * 60,
      'pdt' =>  -7 * 60,
      'pst' =>  -8 * 60,
      'a'   =>  -1 * 60,
      'b'   =>  -2 * 60,
      'c'   =>  -3 * 60,
      'd'   =>  -4 * 60,
      'e'   =>  -5 * 60,
      'f'   =>  -6 * 60,
      'g'   =>  -7 * 60,
      'h'   =>  -8 * 60,
      'i'   =>  -9 * 60,
      # j not use
      'k'   => -10 * 60,
      'l'   => -11 * 60,
      'm'   => -12 * 60,
      'n'   =>   1 * 60,
      'o'   =>   2 * 60,
      'p'   =>   3 * 60,
      'q'   =>   4 * 60,
      'r'   =>   5 * 60,
      's'   =>   6 * 60,
      't'   =>   7 * 60,
      'u'   =>   8 * 60,
      'v'   =>   9 * 60,
      'w'   =>  10 * 60,
      'x'   =>  11 * 60,
      'y'   =>  12 * 60,
      'z'   =>   0 * 60
    }
    #:startdoc:

    # Takes a time zone string from an EMail and converts it to Unix Time (seconds)
    def timezone_string_to_unixtime( str )
      if m = /([\+\-])(\d\d?)(\d\d)/.match(str)
        sec = (m[2].to_i * 60 + m[3].to_i) * 60
        m[1] == '-' ? -sec : sec
      else
        min = ZONESTR_TABLE[str.downcase] or
                raise SyntaxError, "wrong timezone format '#{str}'"
        min * 60
      end
    end

    #:stopdoc:
    WDAY = %w( Sun Mon Tue Wed Thu Fri Sat TMailBUG )
    MONTH = %w( TMailBUG Jan Feb Mar Apr May Jun
                         Jul Aug Sep Oct Nov Dec TMailBUG )

    def time2str( tm )
      # [ruby-list:7928]
      gmt = Time.at(tm.to_i)
      gmt.gmtime
      offset = tm.to_i - Time.local(*gmt.to_a[0,6].reverse).to_i

      # DO NOT USE strftime: setlocale() breaks it
      sprintf '%s, %s %s %d %02d:%02d:%02d %+.2d%.2d',
              WDAY[tm.wday], tm.mday, MONTH[tm.month],
              tm.year, tm.hour, tm.min, tm.sec,
              *(offset / 60).divmod(60)
    end


    MESSAGE_ID = /<[^\@>]+\@[^>]+>/

    def message_id?( str )
      MESSAGE_ID === str
    end


    MIME_ENCODED = /=\?[^\s?=]+\?[QB]\?[^\s?=]+\?=/i

    def mime_encoded?( str )
      MIME_ENCODED === str
    end


    def decode_params( hash )
      new = Hash.new
      encoded = nil
      hash.each do |key, value|
        if m = /\*(?:(\d+)\*)?\z/.match(key)
          ((encoded ||= {})[m.pre_match] ||= [])[(m[1] || 0).to_i] = value
        else
          new[key] = to_kcode(value)
        end
      end
      if encoded
        encoded.each do |key, strings|
          new[key] = decode_RFC2231(strings.join(''))
        end
      end

      new
    end

    NKF_FLAGS = {
      'EUC'  => '-e -m',
      'SJIS' => '-s -m'
    }

    def to_kcode( str )
      flag = NKF_FLAGS[TMail.KCODE] or return str
      NKF.nkf(flag, str)
    end

    RFC2231_ENCODED = /\A(?:iso-2022-jp|euc-jp|shift_jis|us-ascii)?'[a-z]*'/in

    def decode_RFC2231( str )
      m = RFC2231_ENCODED.match(str) or return str
      begin
        to_kcode(m.post_match.gsub(/%[\da-f]{2}/in) {|s| s[1,2].hex.chr })
      rescue
        m.post_match.gsub(/%[\da-f]{2}/in, "")
      end
    end

    def quote_boundary
      # Make sure the Content-Type boundary= parameter is quoted if it contains illegal characters
      # (to ensure any special characters in the boundary text are escaped from the parser
      # (such as = in MS Outlook's boundary text))
      if @body =~ /^(.*)boundary=(.*)$/m
        preamble = $1
        remainder = $2
        if remainder =~ /;/
          remainder =~ /^(.*?)(;.*)$/m
          boundary_text = $1
          post = $2.chomp
        else
          boundary_text = remainder.chomp
        end
        if boundary_text =~ /[\/\?\=]/
          boundary_text = "\"#{boundary_text}\"" unless boundary_text =~ /^".*?"$/
          @body = "#{preamble}boundary=#{boundary_text}#{post}"
        end
      end
    end

    # AppleMail generates illegal character contained Content-Type parameter like:
    #   name==?ISO-2022-JP?B?...=?=
    # so quote. (This case is only value fits in one line.)
    def quote_unquoted_bencode
      @body = @body.gsub(%r"(;\s+[-a-z]+=)(=\?.+?)([;\r\n ]|\z)"m) {
        head, should_quoted, tail = $~.captures
        # head: "; name="
        # should_quoted: "=?ISO-2022-JP?B?...=?="

        head << quote_token(should_quoted) << tail
      }
    end

    # AppleMail generates name=filename attributes in the content type that
    # contain spaces.  Need to handle this so the TMail Parser can.
    def quote_unquoted_name
      @body = @body.gsub(%r|(name=)([\w\s.]+)(.*)|m) {
        head, should_quoted, tail = $~.captures
        # head: "; name="
        # should_quoted: "=?ISO-2022-JP?B?...=?="
        head  << quote_token(should_quoted) << tail
      }
    end

    #:startdoc:

  end

end

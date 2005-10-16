#
# header.rb
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

require 'tmail/encode'
require 'tmail/address'
require 'tmail/parser'
require 'tmail/config'
require 'tmail/utils'


module TMail

  class HeaderField

    include TextUtils

    class << self

      alias newobj new

      def new( name, body, conf = DEFAULT_CONFIG )
        klass = FNAME_TO_CLASS[name.downcase] || UnstructuredHeader
        klass.newobj body, conf
      end

      def new_from_port( port, name, conf = DEFAULT_CONFIG )
        re = Regep.new('\A(' + Regexp.quote(name) + '):', 'i')
        str = nil
        port.ropen {|f|
            f.each do |line|
              if m = re.match(line)            then str = m.post_match.strip
              elsif str and /\A[\t ]/ === line then str << ' ' << line.strip
              elsif /\A-*\s*\z/ === line       then break
              elsif str                        then break
              end
            end
        }
        new(name, str, Config.to_config(conf))
      end

      def internal_new( name, conf )
        FNAME_TO_CLASS[name].newobj('', conf, true)
      end

    end   # class << self

    def initialize( body, conf, intern = false )
      @body = body
      @config = conf

      @illegal = false
      @parsed = false
      if intern
        @parsed = true
        parse_init
      end
    end

    def inspect
      "#<#{self.class} #{@body.inspect}>"
    end

    def illegal?
      @illegal
    end

    def empty?
      ensure_parsed
      return true if @illegal
      isempty?
    end

    private

    def ensure_parsed
      return if @parsed
      @parsed = true
      parse
    end

    # defabstract parse
    # end

    def clear_parse_status
      @parsed = false
      @illegal = false
    end

    public

    def body
      ensure_parsed
      v = Decoder.new(s = '')
      do_accept v
      v.terminate
      s
    end

    def body=( str )
      @body = str
      clear_parse_status
    end

    include StrategyInterface

    def accept( strategy, dummy1 = nil, dummy2 = nil )
      ensure_parsed
      do_accept strategy
      strategy.terminate
    end

    # abstract do_accept

  end


  class UnstructuredHeader < HeaderField

    def body
      ensure_parsed
      @body
    end

    def body=( arg )
      ensure_parsed
      @body = arg
    end

    private

    def parse_init
    end

    def parse
      @body = Decoder.decode(@body.gsub(/\n|\r\n|\r/, ''))
    end

    def isempty?
      not @body
    end

    def do_accept( strategy )
      strategy.text @body
    end

  end


  class StructuredHeader < HeaderField

    def comments
      ensure_parsed
      @comments
    end

    private

    def parse
      save = nil

      begin
        parse_init
        do_parse
      rescue SyntaxError
        if not save and mime_encoded? @body
          save = @body
          @body = Decoder.decode(save)
          retry
        elsif save
          @body = save
        end

        @illegal = true
        raise if @config.strict_parse?
      end
    end

    def parse_init
      @comments = []
      init
    end

    def do_parse
      obj = Parser.parse(self.class::PARSE_TYPE, @body, @comments)
      set obj if obj
    end

  end


  class DateTimeHeader < StructuredHeader

    PARSE_TYPE = :DATETIME

    def date
      ensure_parsed
      @date
    end

    def date=( arg )
      ensure_parsed
      @date = arg
    end

    private

    def init
      @date = nil
    end

    def set( t )
      @date = t
    end

    def isempty?
      not @date
    end

    def do_accept( strategy )
      strategy.meta time2str(@date)
    end

  end


  class AddressHeader < StructuredHeader

    PARSE_TYPE = :MADDRESS

    def addrs
      ensure_parsed
      @addrs
    end

    private

    def init
      @addrs = []
    end

    def set( a )
      @addrs = a
    end

    def isempty?
      @addrs.empty?
    end

    def do_accept( strategy )
      first = true
      @addrs.each do |a|
        if first
          first = false
        else
          strategy.meta ','
          strategy.space
        end
        a.accept strategy
      end

      @comments.each do |c|
        strategy.space
        strategy.meta '('
        strategy.text c
        strategy.meta ')'
      end
    end

  end


  class ReturnPathHeader < AddressHeader

    PARSE_TYPE = :RETPATH

    def addr
      addrs()[0]
    end

    def spec
      a = addr() or return nil
      a.spec
    end

    def routes
      a = addr() or return nil
      a.routes
    end

    private

    def do_accept( strategy )
      a = addr()

      strategy.meta '<'
      unless a.routes.empty?
        strategy.meta a.routes.map {|i| '@' + i }.join(',')
        strategy.meta ':'
      end
      spec = a.spec
      strategy.meta spec if spec
      strategy.meta '>'
    end

  end


  class SingleAddressHeader < AddressHeader

    def addr
      addrs()[0]
    end

    private

    def do_accept( strategy )
      a = addr()
      a.accept strategy
      @comments.each do |c|
        strategy.space
        strategy.meta '('
        strategy.text c
        strategy.meta ')'
      end
    end

  end


  class MessageIdHeader < StructuredHeader

    def id
      ensure_parsed
      @id
    end

    def id=( arg )
      ensure_parsed
      @id = arg
    end

    private

    def init
      @id = nil
    end

    def isempty?
      not @id
    end

    def do_parse
      @id = @body.slice(MESSAGE_ID) or
              raise SyntaxError, "wrong Message-ID format: #{@body}"
    end

    def do_accept( strategy )
      strategy.meta @id
    end

  end


  class ReferencesHeader < StructuredHeader

    def refs
      ensure_parsed
      @refs
    end

    def each_id
      self.refs.each do |i|
        yield i if MESSAGE_ID === i
      end
    end

    def ids
      ensure_parsed
      @ids
    end

    def each_phrase
      self.refs.each do |i|
        yield i unless MESSAGE_ID === i
      end
    end

    def phrases
      ret = []
      each_phrase {|i| ret.push i }
      ret
    end

    private

    def init
      @refs = []
      @ids = []
    end

    def isempty?
      @ids.empty?
    end

    def do_parse
      str = @body
      while m = MESSAGE_ID.match(str)
        pre = m.pre_match.strip
        @refs.push pre unless pre.empty?
        @refs.push s = m[0]
        @ids.push s
        str = m.post_match
      end
      str = str.strip
      @refs.push str unless str.empty?
    end

    def do_accept( strategy )
      first = true
      @ids.each do |i|
        if first
          first = false
        else
          strategy.space
        end
        strategy.meta i
      end
    end

  end


  class ReceivedHeader < StructuredHeader

    PARSE_TYPE = :RECEIVED

    def from
      ensure_parsed
      @from
    end

    def from=( arg )
      ensure_parsed
      @from = arg
    end

    def by
      ensure_parsed
      @by
    end

    def by=( arg )
      ensure_parsed
      @by = arg
    end

    def via
      ensure_parsed
      @via
    end

    def via=( arg )
      ensure_parsed
      @via = arg
    end

    def with
      ensure_parsed
      @with
    end

    def id
      ensure_parsed
      @id
    end

    def id=( arg )
      ensure_parsed
      @id = arg
    end

    def _for
      ensure_parsed
      @_for
    end

    def _for=( arg )
      ensure_parsed
      @_for = arg
    end

    def date
      ensure_parsed
      @date
    end

    def date=( arg )
      ensure_parsed
      @date = arg
    end

    private

    def init
      @from = @by = @via = @with = @id = @_for = nil
      @with = []
      @date = nil
    end

    def set( args )
      @from, @by, @via, @with, @id, @_for, @date = *args
    end

    def isempty?
      @with.empty? and not (@from or @by or @via or @id or @_for or @date)
    end

    def do_accept( strategy )
      list = []
      list.push 'from '  + @from       if @from
      list.push 'by '    + @by         if @by
      list.push 'via '   + @via        if @via
      @with.each do |i|
        list.push 'with ' + i
      end
      list.push 'id '    + @id         if @id
      list.push 'for <'  + @_for + '>' if @_for

      first = true
      list.each do |i|
        strategy.space unless first
        strategy.meta i
        first = false
      end
      if @date
        strategy.meta ';'
        strategy.space
        strategy.meta time2str(@date)
      end
    end

  end


  class KeywordsHeader < StructuredHeader

    PARSE_TYPE = :KEYWORDS

    def keys
      ensure_parsed
      @keys
    end

    private

    def init
      @keys = []
    end

    def set( a )
      @keys = a
    end

    def isempty?
      @keys.empty?
    end

    def do_accept( strategy )
      first = true
      @keys.each do |i|
        if first
          first = false
        else
          strategy.meta ','
        end
        strategy.meta i
      end
    end

  end


  class EncryptedHeader < StructuredHeader

    PARSE_TYPE = :ENCRYPTED

    def encrypter
      ensure_parsed
      @encrypter
    end

    def encrypter=( arg )
      ensure_parsed
      @encrypter = arg
    end

    def keyword
      ensure_parsed
      @keyword
    end

    def keyword=( arg )
      ensure_parsed
      @keyword = arg
    end

    private

    def init
      @encrypter = nil
      @keyword = nil
    end

    def set( args )
      @encrypter, @keyword = args
    end

    def isempty?
      not (@encrypter or @keyword)
    end

    def do_accept( strategy )
      if @key
        strategy.meta @encrypter + ','
        strategy.space
        strategy.meta @keyword
      else
        strategy.meta @encrypter
      end
    end

  end


  class MimeVersionHeader < StructuredHeader

    PARSE_TYPE = :MIMEVERSION

    def major
      ensure_parsed
      @major
    end

    def major=( arg )
      ensure_parsed
      @major = arg
    end

    def minor
      ensure_parsed
      @minor
    end

    def minor=( arg )
      ensure_parsed
      @minor = arg
    end

    def version
      sprintf('%d.%d', major, minor)
    end

    private

    def init
      @major = nil
      @minor = nil
    end

    def set( args )
      @major, @minor = *args
    end

    def isempty?
      not (@major or @minor)
    end

    def do_accept( strategy )
      strategy.meta sprintf('%d.%d', @major, @minor)
    end

  end


  class ContentTypeHeader < StructuredHeader

    PARSE_TYPE = :CTYPE

    def main_type
      ensure_parsed
      @main
    end

    def main_type=( arg )
      ensure_parsed
      @main = arg.downcase
    end

    def sub_type
      ensure_parsed
      @sub
    end

    def sub_type=( arg )
      ensure_parsed
      @sub = arg.downcase
    end

    def content_type
      ensure_parsed
      @sub ? sprintf('%s/%s', @main, @sub) : @main
    end

    def params
      ensure_parsed
      @params
    end

    def []( key )
      ensure_parsed
      @params and @params[key]
    end

    def []=( key, val )
      ensure_parsed
      (@params ||= {})[key] = val
    end

    private

    def init
      @main = @sub = @params = nil
    end

    def set( args )
      @main, @sub, @params = *args
    end

    def isempty?
      not (@main or @sub)
    end

    def do_accept( strategy )
      if @sub
        strategy.meta sprintf('%s/%s', @main, @sub)
      else
        strategy.meta @main
      end
      @params.each do |k,v|
        if v
          strategy.meta ';'
          strategy.space
          strategy.kv_pair k, v
        end
      end
    end

  end


  class ContentTransferEncodingHeader < StructuredHeader

    PARSE_TYPE = :CENCODING

    def encoding
      ensure_parsed
      @encoding
    end

    def encoding=( arg )
      ensure_parsed
      @encoding = arg
    end

    private

    def init
      @encoding = nil
    end

    def set( s )
      @encoding = s
    end

    def isempty?
      not @encoding
    end

    def do_accept( strategy )
      strategy.meta @encoding.capitalize
    end

  end


  class ContentDispositionHeader < StructuredHeader

    PARSE_TYPE = :CDISPOSITION

    def disposition
      ensure_parsed
      @disposition
    end

    def disposition=( str )
      ensure_parsed
      @disposition = str.downcase
    end

    def params
      ensure_parsed
      @params
    end

    def []( key )
      ensure_parsed
      @params and @params[key]
    end

    def []=( key, val )
      ensure_parsed
      (@params ||= {})[key] = val
    end

    private

    def init
      @disposition = @params = nil
    end

    def set( args )
      @disposition, @params = *args
    end

    def isempty?
      not @disposition and (not @params or @params.empty?)
    end

    def do_accept( strategy )
      strategy.meta @disposition
      @params.each do |k,v|
        strategy.meta ';'
        strategy.space
        strategy.kv_pair k, v
      end
    end
      
  end


  class HeaderField   # redefine

    FNAME_TO_CLASS = {
      'date'                      => DateTimeHeader,
      'resent-date'               => DateTimeHeader,
      'to'                        => AddressHeader,
      'cc'                        => AddressHeader,
      'bcc'                       => AddressHeader,
      'from'                      => AddressHeader,
      'reply-to'                  => AddressHeader,
      'resent-to'                 => AddressHeader,
      'resent-cc'                 => AddressHeader,
      'resent-bcc'                => AddressHeader,
      'resent-from'               => AddressHeader,
      'resent-reply-to'           => AddressHeader,
      'sender'                    => SingleAddressHeader,
      'resent-sender'             => SingleAddressHeader,
      'return-path'               => ReturnPathHeader,
      'message-id'                => MessageIdHeader,
      'resent-message-id'         => MessageIdHeader,
      'in-reply-to'               => ReferencesHeader,
      'received'                  => ReceivedHeader,
      'references'                => ReferencesHeader,
      'keywords'                  => KeywordsHeader,
      'encrypted'                 => EncryptedHeader,
      'mime-version'              => MimeVersionHeader,
      'content-type'              => ContentTypeHeader,
      'content-transfer-encoding' => ContentTransferEncodingHeader,
      'content-disposition'       => ContentDispositionHeader,
      'content-id'                => MessageIdHeader,
      'subject'                   => UnstructuredHeader,
      'comments'                  => UnstructuredHeader,
      'content-description'       => UnstructuredHeader
    }

  end

end   # module TMail

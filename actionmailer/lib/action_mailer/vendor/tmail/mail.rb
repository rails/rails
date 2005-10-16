#
# mail.rb
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

require 'tmail/facade'
require 'tmail/encode'
require 'tmail/header'
require 'tmail/port'
require 'tmail/config'
require 'tmail/utils'
require 'tmail/attachments'
require 'tmail/quoting'
require 'socket'


module TMail

  class Mail

    class << self
      def load( fname )
        new(FilePort.new(fname))
      end

      alias load_from load
      alias loadfrom load

      def parse( str )
        new(StringPort.new(str))
      end
    end

    def initialize( port = nil, conf = DEFAULT_CONFIG )
      @port = port || StringPort.new
      @config = Config.to_config(conf)

      @header      = {}
      @body_port   = nil
      @body_parsed = false
      @epilogue    = ''
      @parts       = []

      @port.ropen {|f|
          parse_header f
          parse_body f unless @port.reproducible?
      }
    end

    attr_reader :port

    def inspect
      "\#<#{self.class} port=#{@port.inspect} bodyport=#{@body_port.inspect}>"
    end

    #
    # to_s interfaces
    #

    public

    include StrategyInterface

    def write_back( eol = "\n", charset = 'e' )
      parse_body
      @port.wopen {|stream| encoded eol, charset, stream }
    end

    def accept( strategy )
      with_multipart_encoding(strategy) {
          ordered_each do |name, field|
            next if field.empty?
            strategy.header_name canonical(name)
            field.accept strategy
            strategy.puts
          end
          strategy.puts
          body_port().ropen {|r|
              strategy.write r.read
          }
      }
    end

    private

    def canonical( name )
      name.split(/-/).map {|s| s.capitalize }.join('-')
    end

    def with_multipart_encoding( strategy )
      if parts().empty?    # DO NOT USE @parts
        yield

      else
        bound = ::TMail.new_boundary
        if @header.key? 'content-type'
          @header['content-type'].params['boundary'] = bound
        else
          store 'Content-Type', %<multipart/mixed; boundary="#{bound}">
        end

        yield

        parts().each do |tm|
          strategy.puts
          strategy.puts '--' + bound
          tm.accept strategy
        end
        strategy.puts
        strategy.puts '--' + bound + '--'
        strategy.write epilogue()
      end
    end

    ###
    ### header
    ###

    public

    ALLOW_MULTIPLE = {
      'received'          => true,
      'resent-date'       => true,
      'resent-from'       => true,
      'resent-sender'     => true,
      'resent-to'         => true,
      'resent-cc'         => true,
      'resent-bcc'        => true,
      'resent-message-id' => true,
      'comments'          => true,
      'keywords'          => true
    }
    USE_ARRAY = ALLOW_MULTIPLE

    def header
      @header.dup
    end

    def []( key )
      @header[key.downcase]
    end

    def sub_header(key, param)
      (hdr = self[key]) ? hdr[param] : nil
    end

    alias fetch []

    def []=( key, val )
      dkey = key.downcase

      if val.nil?
        @header.delete dkey
        return nil
      end

      case val
      when String
        header = new_hf(key, val)
      when HeaderField
        ;
      when Array
        ALLOW_MULTIPLE.include? dkey or
                raise ArgumentError, "#{key}: Header must not be multiple"
        @header[dkey] = val
        return val
      else
        header = new_hf(key, val.to_s)
      end
      if ALLOW_MULTIPLE.include? dkey
        (@header[dkey] ||= []).push header
      else
        @header[dkey] = header
      end

      val
    end

    alias store []=

    def each_header
      @header.each do |key, val|
        [val].flatten.each {|v| yield key, v }
      end
    end

    alias each_pair each_header

    def each_header_name( &block )
      @header.each_key(&block)
    end

    alias each_key each_header_name

    def each_field( &block )
      @header.values.flatten.each(&block)
    end

    alias each_value each_field

    FIELD_ORDER = %w(
      return-path received
      resent-date resent-from resent-sender resent-to
      resent-cc resent-bcc resent-message-id
      date from sender reply-to to cc bcc
      message-id in-reply-to references
      subject comments keywords
      mime-version content-type content-transfer-encoding
      content-disposition content-description
    )

    def ordered_each
      list = @header.keys
      FIELD_ORDER.each do |name|
        if list.delete(name)
          [@header[name]].flatten.each {|v| yield name, v }
        end
      end
      list.each do |name|
        [@header[name]].flatten.each {|v| yield name, v }
      end
    end

    def clear
      @header.clear
    end

    def delete( key )
      @header.delete key.downcase
    end

    def delete_if
      @header.delete_if do |key,val|
        if Array === val
          val.delete_if {|v| yield key, v }
          val.empty?
        else
          yield key, val
        end
      end
    end

    def keys
      @header.keys
    end

    def key?( key )
      @header.key? key.downcase
    end

    def values_at( *args )
      args.map {|k| @header[k.downcase] }.flatten
    end

    alias indexes values_at
    alias indices values_at

    private

    def parse_header( f )
      name = field = nil
      unixfrom = nil

      while line = f.gets
        case line
        when /\A[ \t]/             # continue from prev line
          raise SyntaxError, 'mail is began by space' unless field
          field << ' ' << line.strip

        when /\A([^\: \t]+):\s*/   # new header line
          add_hf name, field if field
          name = $1
          field = $' #.strip

        when /\A\-*\s*\z/          # end of header
          add_hf name, field if field
          name = field = nil
          break

        when /\AFrom (\S+)/
          unixfrom = $1

  		  when /^charset=.*/
				
        else
          raise SyntaxError, "wrong mail header: '#{line.inspect}'"
        end
      end
      add_hf name, field if name

      if unixfrom
        add_hf 'Return-Path', "<#{unixfrom}>" unless @header['return-path']
      end
    end

    def add_hf( name, field )
      key = name.downcase
      field = new_hf(name, field)

      if ALLOW_MULTIPLE.include? key
        (@header[key] ||= []).push field
      else
        @header[key] = field
      end
    end

    def new_hf( name, field )
      HeaderField.new(name, field, @config)
    end

    ###
    ### body
    ###

    public

    def body_port
      parse_body
      @body_port
    end

    def each( &block )
      body_port().ropen {|f| f.each(&block) }
    end

    def quoted_body
      parse_body
      @body_port.ropen {|f|
          return f.read
      }
    end

    def body=( str )
      parse_body
      @body_port.wopen {|f| f.write str }
      str
    end

    alias preamble  body
    alias preamble= body=

    def epilogue
      parse_body
      @epilogue.dup
    end

    def epilogue=( str )
      parse_body
      @epilogue = str
      str
    end

    def parts
      parse_body
      @parts
    end
    
    def each_part( &block )
      parts().each(&block)
    end

    private

    def parse_body( f = nil )
      return if @body_parsed
      if f
        parse_body_0 f
      else
        @port.ropen {|f|
            skip_header f
            parse_body_0 f
        }
      end
      @body_parsed = true
    end

    def skip_header( f )
      while line = f.gets
        return if /\A[\r\n]*\z/ === line
      end
    end

    def parse_body_0( f )
      if multipart?
        read_multipart f
      else
        @body_port = @config.new_body_port(self)
        @body_port.wopen {|w|
            w.write f.read
        }
      end
    end
    
    def read_multipart( src )
      bound = @header['content-type'].params['boundary']
      is_sep = /\A--#{Regexp.quote bound}(?:--)?[ \t]*(?:\n|\r\n|\r)/
      lastbound = "--#{bound}--"

      ports = [ @config.new_preamble_port(self) ]
      begin
        f = ports.last.wopen
        while line = src.gets
          if is_sep === line
            f.close
            break if line.strip == lastbound
            ports.push @config.new_part_port(self)
            f = ports.last.wopen
          else
            f << line
          end
        end
        @epilogue = (src.read || '')
      ensure
        f.close if f and not f.closed?
      end

      @body_port = ports.shift
      @parts = ports.map {|p| self.class.new(p, @config) }
    end

  end   # class Mail

end   # module TMail

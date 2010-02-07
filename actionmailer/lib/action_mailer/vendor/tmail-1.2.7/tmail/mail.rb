=begin rdoc

= Mail class

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

 

require 'tmail/interface'
require 'tmail/encode'
require 'tmail/header'
require 'tmail/port'
require 'tmail/config'
require 'tmail/utils'
require 'tmail/attachments'
require 'tmail/quoting'
require 'socket'

module TMail

  # == Mail Class
  # 
  # Accessing a TMail object done via the TMail::Mail class.  As email can be fairly complex
  # creatures, you will find a large amount of accessor and setter methods in this class!
  # 
  # Most of the below methods handle the header, in fact, what TMail does best is handle the
  # header of the email object.  There are only a few methods that deal directly with the body
  # of the email, such as base64_encode and base64_decode.
  # 
  # === Using TMail inside your code
  # 
  # The usual way is to install the gem (see the {README}[link:/README] on how to do this) and
  # then put at the top of your class:
  # 
  #  require 'tmail'
  # 
  # You can then create a new TMail object in your code with:
  # 
  #  @email = TMail::Mail.new
  # 
  # Or if you have an email as a string, you can initialize a new TMail::Mail object and get it
  # to parse that string for you like so:
  # 
  #  @email = TMail::Mail.parse(email_text)
  # 
  # You can also read a single email off the disk, for example:
  # 
  #  @email = TMail::Mail.load('filename.txt')
  # 
  # Also, you can read a mailbox (usual unix mbox format) and end up with an array of TMail
  # objects by doing something like this:
  # 
  #  # Note, we pass true as the last variable to open the mailbox read only
  #  mailbox = TMail::UNIXMbox.new("mailbox", nil, true)
  #  @emails = []
  #  mailbox.each_port { |m| @emails << TMail::Mail.new(m) }
  #
  class Mail

    class << self
      
      # Opens an email that has been saved out as a file by itself.
      # 
      # This function will read a file non-destructively and then parse
      # the contents and return a TMail::Mail object.
      # 
      # Does not handle multiple email mailboxes (like a unix mbox) for that
      # use the TMail::UNIXMbox class.
      # 
      # Example:
      #  mail = TMail::Mail.load('filename')
      # 
      def load( fname )
        new(FilePort.new(fname))
      end

      alias load_from load
      alias loadfrom load
      
      # Parses an email from the supplied string and returns a TMail::Mail
      # object.
      # 
      # Example:
      #  require 'rubygems'; require 'tmail'
      #  email_string =<<HEREDOC
      #  To: mikel@lindsaar.net
      #  From: mikel@me.com
      #  Subject: This is a short Email
      #  
      #  Hello there Mikel!
      #  
      #  HEREDOC
      #  mail = TMail::Mail.parse(email_string)
      #  #=> #<TMail::Mail port=#<TMail::StringPort:id=0xa30ac0> bodyport=nil>
      #  mail.body
      #  #=> "Hello there Mikel!\n\n"
      def parse( str )
        new(StringPort.new(str))
      end

    end

    def initialize( port = nil, conf = DEFAULT_CONFIG ) #:nodoc:
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

    # Provides access to the port this email is using to hold it's data
    # 
    # Example:
    #  mail = TMail::Mail.parse(email_string)
    #  mail.port
    #  #=> #<TMail::StringPort:id=0xa2c952>
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

    # Returns a TMail::AddressHeader object of the field you are querying.
    # Examples:
    #  @mail['from']  #=> #<TMail::AddressHeader "mikel@test.com.au">
    #  @mail['to']    #=> #<TMail::AddressHeader "mikel@test.com.au">
    #
    # You can get the string value of this by passing "to_s" to the query:
    # Example:
    #  @mail['to'].to_s #=> "mikel@test.com.au"
    def []( key )
      @header[key.downcase]
    end

    def sub_header(key, param)
      (hdr = self[key]) ? hdr[param] : nil
    end

    alias fetch []

    # Allows you to set or delete TMail header objects at will.
    # Examples:
    #  @mail = TMail::Mail.new
    #  @mail['to'].to_s       # => 'mikel@test.com.au'
    #  @mail['to'] = 'mikel@elsewhere.org'
    #  @mail['to'].to_s       # => 'mikel@elsewhere.org'
    #  @mail.encoded          # => "To: mikel@elsewhere.org\r\n\r\n"
    #  @mail['to'] = nil
    #  @mail['to'].to_s       # => nil
    #  @mail.encoded          # => "\r\n"
    # 
    # Note: setting mail[] = nil actually deletes the header field in question from the object,
    # it does not just set the value of the hash to nil
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
    
    # Allows you to loop through each header in the TMail::Mail object in a block
    # Example:
    #   @mail['to'] = 'mikel@elsewhere.org'
    #   @mail['from'] = 'me@me.com'
    #   @mail.each_header { |k,v| puts "#{k} = #{v}" }
    #   # => from = me@me.com
    #   # => to = mikel@elsewhere.org
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
      body_port.ropen {|f| return f.read }
    end

    def quoted_body= str
      body_port.wopen { |f| f.write str }
      str
    end

    def body=( str )
      # Sets the body of the email to a new (encoded) string.
      # 
      # We also reparses the email if the body is ever reassigned, this is a performance hit, however when
      # you assign the body, you usually want to be able to make sure that you can access the attachments etc.
      # 
      # Usage:
      # 
      #  mail.body = "Hello, this is\nthe body text"
      #  # => "Hello, this is\nthe body"
      #  mail.body
      #  # => "Hello, this is\nthe body"
      @body_parsed = false
      parse_body(StringInput.new(str))
      parse_body
      @body_port.wopen {|f| f.write str }
      str
    end

    alias preamble  quoted_body
    alias preamble= quoted_body=

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
    
    # Returns true if the content type of this part of the email is
    # a disposition attachment
    def disposition_is_attachment?
      (self['content-disposition'] && self['content-disposition'].disposition == "attachment")
    end

    # Returns true if this part's content main type is text, else returns false.
    # By main type is meant "text/plain" is text.  "text/html" is text
    def content_type_is_text?
      self.header['content-type'] && (self.header['content-type'].main_type != "text")
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
      bound = @header['content-type'].params['boundary'] || ::TMail.new_boundary
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

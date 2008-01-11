#
# facade.rb
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

require 'tmail/utils'


module TMail

  class Mail

    def header_string( name, default = nil )
      h = @header[name.downcase] or return default
      h.to_s
    end

    ###
    ### attributes
    ###

    include TextUtils

    def set_string_array_attr( key, strs )
      strs.flatten!
      if strs.empty?
        @header.delete key.downcase
      else
        store key, strs.join(', ')
      end
      strs
    end
    private :set_string_array_attr

    def set_string_attr( key, str )
      if str
        store key, str
      else
        @header.delete key.downcase
      end
      str
    end
    private :set_string_attr

    def set_addrfield( name, arg )
      if arg
        h = HeaderField.internal_new(name, @config)
        h.addrs.replace [arg].flatten
        @header[name] = h
      else
        @header.delete name
      end
      arg
    end
    private :set_addrfield

    def addrs2specs( addrs )
      return nil unless addrs
      list = addrs.map {|addr|
          if addr.address_group?
          then addr.map {|a| a.spec }
          else addr.spec
          end
      }.flatten
      return nil if list.empty?
      list
    end
    private :addrs2specs


    #
    # date time
    #

    def date( default = nil )
      if h = @header['date']
        h.date
      else
        default
      end
    end

    def date=( time )
      if time
        store 'Date', time2str(time)
      else
        @header.delete 'date'
      end
      time
    end

    def strftime( fmt, default = nil )
      if t = date
        t.strftime(fmt)
      else
        default
      end
    end


    #
    # destination
    #

    def to_addrs( default = nil )
      if h = @header['to']
        h.addrs
      else
        default
      end
    end

    def cc_addrs( default = nil )
      if h = @header['cc']
        h.addrs
      else
        default
      end
    end

    def bcc_addrs( default = nil )
      if h = @header['bcc']
        h.addrs
      else
        default
      end
    end

    def to_addrs=( arg )
      set_addrfield 'to', arg
    end

    def cc_addrs=( arg )
      set_addrfield 'cc', arg
    end

    def bcc_addrs=( arg )
      set_addrfield 'bcc', arg
    end

    def to( default = nil )
      addrs2specs(to_addrs(nil)) || default
    end

    def cc( default = nil )
      addrs2specs(cc_addrs(nil)) || default
    end

    def bcc( default = nil )
      addrs2specs(bcc_addrs(nil)) || default
    end

    def to=( *strs )
      set_string_array_attr 'To', strs
    end

    def cc=( *strs )
      set_string_array_attr 'Cc', strs
    end

    def bcc=( *strs )
      set_string_array_attr 'Bcc', strs
    end


    #
    # originator
    #

    def from_addrs( default = nil )
      if h = @header['from']
        h.addrs
      else
        default
      end
    end

    def from_addrs=( arg )
      set_addrfield 'from', arg
    end

    def from( default = nil )
      addrs2specs(from_addrs(nil)) || default
    end

    def from=( *strs )
      set_string_array_attr 'From', strs
    end

    def friendly_from( default = nil )
      h = @header['from']
      a, = h.addrs
      return default unless a
      return a.phrase if a.phrase
      return h.comments.join(' ') unless h.comments.empty?
      a.spec
    end


    def reply_to_addrs( default = nil )
      if h = @header['reply-to']
        h.addrs
      else
        default
      end
    end

    def reply_to_addrs=( arg )
      set_addrfield 'reply-to', arg
    end

    def reply_to( default = nil )
      addrs2specs(reply_to_addrs(nil)) || default
    end

    def reply_to=( *strs )
      set_string_array_attr 'Reply-To', strs
    end


    def sender_addr( default = nil )
      f = @header['sender'] or return default
      f.addr                or return default
    end

    def sender_addr=( addr )
      if addr
        h = HeaderField.internal_new('sender', @config)
        h.addr = addr
        @header['sender'] = h
      else
        @header.delete 'sender'
      end
      addr
    end

    def sender( default )
      f = @header['sender'] or return default
      a = f.addr            or return default
      a.spec
    end

    def sender=( str )
      set_string_attr 'Sender', str
    end


    #
    # subject
    #

    def subject( default = nil )
      if h = @header['subject']
        h.body
      else
        default
      end
    end
    alias quoted_subject subject

    def subject=( str )
      set_string_attr 'Subject', str
    end


    #
    # identity & threading
    #

    def message_id( default = nil )
      if h = @header['message-id']
        h.id || default
      else
        default
      end
    end

    def message_id=( str )
      set_string_attr 'Message-Id', str
    end

    def in_reply_to( default = nil )
      if h = @header['in-reply-to']
        h.ids
      else
        default
      end
    end

    def in_reply_to=( *idstrs )
      set_string_array_attr 'In-Reply-To', idstrs
    end

    def references( default = nil )
      if h = @header['references']
        h.refs
      else
        default
      end
    end

    def references=( *strs )
      set_string_array_attr 'References', strs
    end


    #
    # MIME headers
    #

    def mime_version( default = nil )
      if h = @header['mime-version']
        h.version || default
      else
        default
      end
    end

    def mime_version=( m, opt = nil )
      if opt
        if h = @header['mime-version']
          h.major = m
          h.minor = opt
        else
          store 'Mime-Version', "#{m}.#{opt}"
        end
      else
        store 'Mime-Version', m
      end
      m
    end


    def content_type( default = nil )
      if h = @header['content-type']
        h.content_type || default
      else
        default
      end
    end

    def main_type( default = nil )
      if h = @header['content-type']
        h.main_type || default
      else
        default
      end
    end

    def sub_type( default = nil )
      if h = @header['content-type']
        h.sub_type || default
      else
        default
      end
    end

    def set_content_type( str, sub = nil, param = nil )
      if sub
        main, sub = str, sub
      else
        main, sub = str.split(%r</>, 2)
        raise ArgumentError, "sub type missing: #{str.inspect}" unless sub
      end
      if h = @header['content-type']
        h.main_type = main
        h.sub_type  = sub
        h.params.clear
      else
        store 'Content-Type', "#{main}/#{sub}"
      end
      @header['content-type'].params.replace param if param

      str
    end

    alias content_type= set_content_type
    
    def type_param( name, default = nil )
      if h = @header['content-type']
        h[name] || default
      else
        default
      end
    end

    def charset( default = nil )
      if h = @header['content-type']
        h['charset'] or default
      else
        default
      end
    end

    def charset=( str )
      if str
        if h = @header[ 'content-type' ]
          h['charset'] = str
        else
          store 'Content-Type', "text/plain; charset=#{str}"
        end
      end
      str
    end


    def transfer_encoding( default = nil )
      if h = @header['content-transfer-encoding']
        h.encoding || default
      else
        default
      end
    end

    def transfer_encoding=( str )
      set_string_attr 'Content-Transfer-Encoding', str
    end

    alias encoding                   transfer_encoding
    alias encoding=                  transfer_encoding=
    alias content_transfer_encoding  transfer_encoding
    alias content_transfer_encoding= transfer_encoding=


    def disposition( default = nil )
      if h = @header['content-disposition']
        h.disposition || default
      else
        default
      end
    end

    alias content_disposition     disposition

    def set_disposition( str, params = nil )
      if h = @header['content-disposition']
        h.disposition = str
        h.params.clear
      else
        store('Content-Disposition', str)
        h = @header['content-disposition']
      end
      h.params.replace params if params
    end

    alias disposition=            set_disposition
    alias set_content_disposition set_disposition
    alias content_disposition=    set_disposition
    
    def disposition_param( name, default = nil )
      if h = @header['content-disposition']
        h[name] || default
      else
        default
      end
    end

    ###
    ### utils
    ###

    def create_reply
      mail = TMail::Mail.parse('')
      mail.subject = 'Re: ' + subject('').sub(/\A(?:\[[^\]]+\])?(?:\s*Re:)*\s*/i, '')
      mail.to_addrs = reply_addresses([])
      mail.in_reply_to = [message_id(nil)].compact
      mail.references = references([]) + [message_id(nil)].compact
      mail.mime_version = '1.0'
      mail
    end


    def base64_encode
      store 'Content-Transfer-Encoding', 'Base64'
      self.body = Base64.folding_encode(self.body)
    end

    def base64_decode
      if /base64/i === self.transfer_encoding('')
        store 'Content-Transfer-Encoding', '8bit'
        self.body = Base64.decode(self.body, @config.strict_base64decode?)
      end
    end


    def destinations( default = nil )
      ret = []
      %w( to cc bcc ).each do |nm|
        if h = @header[nm]
          h.addrs.each {|i| ret.push i.address }
        end
      end
      ret.empty? ? default : ret
    end

    def each_destination( &block )
      destinations([]).each do |i|
        if Address === i
          yield i
        else
          i.each(&block)
        end
      end
    end

    alias each_dest each_destination


    def reply_addresses( default = nil )
      reply_to_addrs(nil) or from_addrs(nil) or default
    end

    def error_reply_addresses( default = nil )
      if s = sender(nil)
        [s]
      else
        from_addrs(default)
      end
    end


    def multipart?
      main_type('').downcase == 'multipart'
    end

  end   # class Mail

end   # module TMail

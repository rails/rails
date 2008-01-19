=begin rdoc

= Net provides SMTP wrapping

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

require 'nkf'


module TMail

  class Mail

    def send_to( smtp )
      do_send_to(smtp) do
        ready_to_send
      end
    end

    def send_text_to( smtp )
      do_send_to(smtp) do
        ready_to_send
        mime_encode
      end
    end

    def do_send_to( smtp )
      from = from_address or raise ArgumentError, 'no from address'
      (dests = destinations).empty? and raise ArgumentError, 'no receipient'
      yield
      send_to_0 smtp, from, dests
    end
    private :do_send_to

    def send_to_0( smtp, from, to )
      smtp.ready(from, to) do |f|
        encoded "\r\n", 'j', f, ''
      end
    end

    def ready_to_send
      delete_no_send_fields
      add_message_id
      add_date
    end

    NOSEND_FIELDS = %w(
      received
      bcc
    )

    def delete_no_send_fields
      NOSEND_FIELDS.each do |nm|
        delete nm
      end
      delete_if {|n,v| v.empty? }
    end

    def add_message_id( fqdn = nil )
      self.message_id = ::TMail::new_message_id(fqdn)
    end

    def add_date
      self.date = Time.now
    end

    def mime_encode
      if parts.empty?
        mime_encode_singlepart
      else
        mime_encode_multipart true
      end
    end

    def mime_encode_singlepart
      self.mime_version = '1.0'
      b = body
      if NKF.guess(b) != NKF::BINARY
        mime_encode_text b
      else
        mime_encode_binary b
      end
    end

    def mime_encode_text( body )
      self.body = NKF.nkf('-j -m0', body)
      self.set_content_type 'text', 'plain', {'charset' => 'iso-2022-jp'}
      self.encoding = '7bit'
    end

    def mime_encode_binary( body )
      self.body = [body].pack('m')
      self.set_content_type 'application', 'octet-stream'
      self.encoding = 'Base64'
    end

    def mime_encode_multipart( top = true )
      self.mime_version = '1.0' if top
      self.set_content_type 'multipart', 'mixed'
      e = encoding(nil)
      if e and not /\A(?:7bit|8bit|binary)\z/i === e
        raise ArgumentError,
              'using C.T.Encoding with multipart mail is not permitted'
      end
    end
  
  end


  class DeleteFields

    NOSEND_FIELDS = %w(
      received
      bcc
    )

    def initialize( nosend = nil, delempty = true )
      @no_send_fields = nosend || NOSEND_FIELDS.dup
      @delete_empty_fields = delempty
    end

    attr :no_send_fields
    attr :delete_empty_fields, true

    def exec( mail )
      @no_send_fields.each do |nm|
        delete nm
      end
      delete_if {|n,v| v.empty? } if @delete_empty_fields
    end
  
  end


  class AddMessageId

    def initialize( fqdn = nil )
      @fqdn = fqdn
    end

    attr :fqdn, true

    def exec( mail )
      mail.message_id = ::TMail::new_msgid(@fqdn)
    end
  
  end


  class AddDate

    def exec( mail )
      mail.date = Time.now
    end
  
  end


  class MimeEncodeAuto

    def initialize( s = nil, m = nil )
      @singlepart_composer = s || MimeEncodeSingle.new
      @multipart_composer  = m || MimeEncodeMulti.new
    end

    attr :singlepart_composer
    attr :multipart_composer

    def exec( mail )
      if mail._builtin_multipart?
      then @multipart_composer
      else @singlepart_composer end.exec mail
    end
  
  end

  
  class MimeEncodeSingle

    def exec( mail )
      mail.mime_version = '1.0'
      b = mail.body
      if NKF.guess(b) != NKF::BINARY
        on_text b
      else
        on_binary b
      end
    end

    def on_text( body )
      mail.body = NKF.nkf('-j -m0', body)
      mail.set_content_type 'text', 'plain', {'charset' => 'iso-2022-jp'}
      mail.encoding = '7bit'
    end

    def on_binary( body )
      mail.body = [body].pack('m')
      mail.set_content_type 'application', 'octet-stream'
      mail.encoding = 'Base64'
    end
  
  end


  class MimeEncodeMulti

    def exec( mail, top = true )
      mail.mime_version = '1.0' if top
      mail.set_content_type 'multipart', 'mixed'
      e = encoding(nil)
      if e and not /\A(?:7bit|8bit|binary)\z/i === e
        raise ArgumentError,
              'using C.T.Encoding with multipart mail is not permitted'
      end
      mail.parts.each do |m|
        exec m, false if m._builtin_multipart?
      end
    end

  end

end   # module TMail

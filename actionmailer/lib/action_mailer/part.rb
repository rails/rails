require 'action_mailer/adv_attr_accessor'
require 'action_mailer/part_container'
require 'action_mailer/utils'

module ActionMailer
  class Part #:nodoc:
    include ActionMailer::AdvAttrAccessor
    include ActionMailer::PartContainer

    adv_attr_accessor :content_type, :content_disposition, :charset, :body
    adv_attr_accessor :filename, :transfer_encoding, :headers

    def initialize(params)
      @content_type = params[:content_type]
      @content_disposition = params[:disposition] || "inline"
      @charset = params[:charset]
      @body = params[:body]
      @filename = params[:filename]
      @transfer_encoding = params[:transfer_encoding] || "quoted-printable"
      @headers = params[:headers] || {}
      @parts = []
    end

    def to_mail(defaults)
      part = TMail::Mail.new

      if @parts.empty?
        part.content_transfer_encoding = transfer_encoding || "quoted-printable"
        case (transfer_encoding || "").downcase
          when "base64" then
            part.body = TMail::Base64.folding_encode(body)
          when "quoted-printable"
            part.body = [Utils.normalize_new_lines(body)].pack("M*")
          else
            part.body = body
        end

        # Always set the content_type after setting the body and or parts!
        # Also don't set filename and name when there is none (like in
        # non-attachment parts)
        if content_disposition == "attachment"
          part.set_content_type(content_type || defaults.content_type, nil,
            squish("charset" => nil, "name" => filename))
          part.set_content_disposition(content_disposition,
            squish("filename" => filename))
        else
          part.set_content_type(content_type || defaults.content_type, nil,
            "charset" => (charset || defaults.charset))      
          part.set_content_disposition(content_disposition) 
        end        
      else
        if String === body
          part = TMail::Mail.new
          part.body = body
          part.set_content_type content_type, nil, { "charset" => charset }
          part.set_content_disposition "inline"
          m.parts << part
        end
          
        @parts.each do |p|
          prt = (TMail::Mail === p ? p : p.to_mail(defaults))
          part.parts << prt
        end
        
        part.set_content_type(content_type, nil, { "charset" => charset }) if content_type =~ /multipart/
      end
    
      part
    end

    private
      def squish(values={})
        values.delete_if { |k,v| v.nil? }
      end
  end
end

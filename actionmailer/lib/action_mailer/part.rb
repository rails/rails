require 'action_mailer/adv_attr_accessor'
require 'action_mailer/part_container'
require 'action_mailer/utils'

module ActionMailer
  # Represents a subpart of an email message. It shares many similar
  # attributes of ActionMailer::Base.  Although you can create parts manually
  # and add them to the +parts+ list of the mailer, it is easier
  # to use the helper methods in ActionMailer::PartContainer.
  class Part
    include ActionMailer::AdvAttrAccessor
    include ActionMailer::PartContainer

    # Represents the body of the part, as a string. This should not be a
    # Hash (like ActionMailer::Base), but if you want a template to be rendered
    # into the body of a subpart you can do it with the mailer's +render+ method
    # and assign the result here.
    adv_attr_accessor :body
    
    # Specify the charset for this subpart. By default, it will be the charset
    # of the containing part or mailer.
    adv_attr_accessor :charset
    
    # The content disposition of this part, typically either "inline" or
    # "attachment".
    adv_attr_accessor :content_disposition
    
    # The content type of the part.
    adv_attr_accessor :content_type
    
    # The filename to use for this subpart (usually for attachments).
    adv_attr_accessor :filename
    
    # Accessor for specifying additional headers to include with this part.
    adv_attr_accessor :headers
    
    # The transfer encoding to use for this subpart, like "base64" or
    # "quoted-printable".
    adv_attr_accessor :transfer_encoding

    # Create a new part from the given +params+ hash. The valid params keys
    # correspond to the accessors.
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

    # Convert the part to a mail object which can be included in the parts
    # list of another mail object.
    def to_mail(defaults)
      part = TMail::Mail.new

      real_content_type, ctype_attrs = parse_content_type(defaults)

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
          ctype_attrs.delete "charset"
          part.set_content_type(real_content_type, nil,
            squish("name" => filename).merge(ctype_attrs))
          part.set_content_disposition(content_disposition,
            squish("filename" => filename).merge(ctype_attrs))
        else
          part.set_content_type(real_content_type, nil, ctype_attrs)
          part.set_content_disposition(content_disposition) 
        end        
      else
        if String === body
          @parts.unshift Part.new(:charset => charset, :body => @body, :content_type => 'text/plain')
          @body = nil
        end
          
        @parts.each do |p|
          prt = (TMail::Mail === p ? p : p.to_mail(defaults))
          part.parts << prt
        end
        
        part.set_content_type(real_content_type, nil, ctype_attrs) if real_content_type =~ /multipart/
      end

      headers.each { |k,v| part[k] = v }

      part
    end

    private

      def squish(values={})
        values.delete_if { |k,v| v.nil? }
      end
  end
end

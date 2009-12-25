module ActionMailer
  # Accessors and helpers that ActionMailer::Base and ActionMailer::Part have
  # in common. Using these helpers you can easily add subparts or attachments
  # to your message:
  #
  #   def my_mail_message(...)
  #     ...
  #     part "text/plain" do |p|
  #       p.body "hello, world"
  #       p.transfer_encoding "base64"
  #     end
  #
  #     attachment "image/jpg" do |a|
  #       a.body = File.read("hello.jpg")
  #       a.filename = "hello.jpg"
  #     end
  #   end
  module PartContainer
    # The list of subparts of this container
    attr_reader :parts

    # Add a part to a multipart message, with the given content-type. The
    # part itself is yielded to the block so that other properties (charset,
    # body, headers, etc.) can be set on it.
    def part(params)
      params = {:content_type => params} if String === params
      part = Part.new(params)
      yield part if block_given?
      @parts << part
    end

    # Add an attachment to a multipart message. This is simply a part with the
    # content-disposition set to "attachment".
    def attachment(params, &block)
      params = { :content_type => params } if String === params
      params = { :disposition => "attachment",
                 :transfer_encoding => "base64" }.merge(params)
      part(params, &block)
    end

    private

      def normalize_new_lines(text) #:nodoc:
        text.to_s.gsub(/\r\n?/, "\n")
      end

      def setup_multiple_parts(mailer, real_content_type, ctype_attrs) #:nodoc:
        @parts.each do |p|
          part = (TMail::Mail === p ? p : p.to_mail(self))
          mailer.parts << part
        end

        if real_content_type =~ /multipart/
          ctype_attrs.delete "charset"
          mailer.set_content_type(real_content_type, nil, ctype_attrs)
        end
      end

      def parse_content_type(defaults=nil) #:nodoc:
        if content_type.blank? 
          return defaults                                                ? 
            [ defaults.content_type, { 'charset' => defaults.charset } ] : 
            [ nil, {} ] 
        end 
        ctype, *attrs = content_type.split(/;\s*/)
        attrs = attrs.inject({}) { |h,s| k,v = s.split(/=/, 2); h[k] = v; h }
        [ctype, {"charset" => charset || defaults && defaults.charset}.merge(attrs)]
      end

  end
end

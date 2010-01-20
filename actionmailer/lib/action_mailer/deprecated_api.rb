module ActionMailer
  # TODO Remove this module all together in Rails 3.1. Ensure that super
  # hooks in ActionMailer::Base are removed as well.
  # 
  # Moved here to allow us to add the new Mail API
  module DeprecatedApi
    extend ActionMailer::AdvAttrAccessor

    # Add a part to a multipart message, with the given content-type. The
    # part itself is yielded to the block so that other properties (charset,
    # body, headers, etc.) can be set on it.
    def part(params)
      params = {:content_type => params} if String === params

      if custom_headers = params.delete(:headers)
        ActiveSupport::Deprecation.warn('Passing custom headers with :headers => {} is deprecated. ' <<
                                        'Please just pass in custom headers directly.', caller[0,10])
        params.merge!(custom_headers)
      end

      part = Mail::Part.new(params)
      yield part if block_given?
      @parts << part
    end

    # Add an attachment to a multipart message. This is simply a part with the
    # content-disposition set to "attachment".
    def attachment(params, &block)
      super # Run deprecation hooks

      params = { :content_type => params } if String === params
      params = { :content_disposition => "attachment",
                 :content_transfer_encoding => "base64" }.merge(params)

      part(params, &block)
    end

    private
    
    def create_mail #:nodoc:
      m = @message

      m.subject,     = quote_any_if_necessary(charset, subject)
      m.to, m.from   = quote_any_address_if_necessary(charset, recipients, from)
      m.bcc          = quote_address_if_necessary(bcc, charset) unless bcc.nil?
      m.cc           = quote_address_if_necessary(cc, charset) unless cc.nil?
      m.reply_to     = quote_address_if_necessary(reply_to, charset) unless reply_to.nil?
      m.mime_version = mime_version unless mime_version.nil?
      m.date         = sent_on.to_time rescue sent_on if sent_on

      headers.each { |k, v| m[k] = v }

      real_content_type, ctype_attrs = parse_content_type
      main_type, sub_type = split_content_type(real_content_type)

      if @parts.size == 1 && @parts.first.parts.empty?
        m.content_type([main_type, sub_type, ctype_attrs])
        m.body = @parts.first.body.encoded
      else
        @parts.each do |p|
          m.add_part(p)
        end

        m.body.set_sort_order(@implicit_parts_order)
        m.body.sort_parts!

        if real_content_type =~ /multipart/
          ctype_attrs.delete "charset"
          m.content_type([main_type, sub_type, ctype_attrs])
        end
      end

      m.content_transfer_encoding = '8bit' unless m.body.only_us_ascii?
      
      @message
    end

    # Render a message but does not set it as mail body. Useful for rendering
    # data for part and attachments.
    #
    # Examples:
    #
    #   render_message "special_message"
    #   render_message :template => "special_message"
    #   render_message :inline => "<%= 'Hi!' %>"
    #
    # TODO Deprecate me
    def render_message(object)
      case object
      when String
        render_to_body(:template => object)
      else
        render_to_body(object)
      end
    end
    
    # Set up the default values for the various instance variables of this
    # mailer. Subclasses may override this method to provide different
    # defaults.
    def initialize_defaults(method_name) #:nodoc:
      @charset              ||= self.class.default_charset.dup
      @content_type         ||= self.class.default_content_type.dup
      @implicit_parts_order ||= self.class.default_implicit_parts_order.dup
      @mime_version         ||= self.class.default_mime_version.dup if self.class.default_mime_version

      @mailer_name ||= self.class.mailer_name.dup
      @delivery_method = self.class.delivery_method
      @template    ||= method_name

      @parts   ||= []
      @headers ||= {}
      @sent_on ||= Time.now

      super # Run deprecation hooks
    end

    def create_parts #:nodoc:
      super # Run deprecation hooks

      if String === response_body
        @parts.unshift create_inline_part(response_body)
      else
        self.class.template_root.find_all(@template, {}, @mailer_name).each do |template|
          @parts << create_inline_part(render_to_body(:_template => template), template.mime_type)
        end

        if @parts.size > 1
          @content_type = "multipart/alternative" if @content_type !~ /^multipart/
        end

        # If this is a multipart e-mail add the mime_version if it is not
        # already set.
        @mime_version ||= "1.0" if !@parts.empty?
      end
    end

    def create_inline_part(body, mime_type=nil) #:nodoc:
      ct = mime_type || "text/plain"
      main_type, sub_type = split_content_type(ct.to_s)

      Mail::Part.new(
        :content_type => [main_type, sub_type, {:charset => charset}],
        :content_disposition => "inline",
        :body => body
      )
    end
    
    def split_content_type(ct) #:nodoc:
      ct.to_s.split("/")
    end

    def parse_content_type(defaults=nil) #:nodoc:
      if @content_type.blank?
        [ nil, {} ]
      else
        ctype, *attrs = @content_type.split(/;\s*/)
        attrs = attrs.inject({}) { |h,s| k,v = s.split(/\=/, 2); h[k] = v; h }
        [ctype, {"charset" => @charset}.merge(attrs)]
      end
    end

  end
end
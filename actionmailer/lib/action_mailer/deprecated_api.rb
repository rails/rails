module ActionMailer
  # TODO Remove this module all together in Rails 3.1. Ensure that super
  # hooks in ActionMailer::Base are removed as well.
  # 
  # Moved here to allow us to add the new Mail API
  module DeprecatedApi #:nodoc:
    extend ActiveSupport::Concern

    included do
      extend ActionMailer::AdvAttrAccessor

      @@protected_instance_variables = %w(@parts)
      cattr_reader :protected_instance_variables

      # Specify the BCC addresses for the message
      adv_attr_accessor :bcc

      # Specify the CC addresses for the message.
      adv_attr_accessor :cc

      # Specify the charset to use for the message. This defaults to the
      # +default_charset+ specified for ActionMailer::Base.
      adv_attr_accessor :charset

      # Specify the content type for the message. This defaults to <tt>text/plain</tt>
      # in most cases, but can be automatically set in some situations.
      adv_attr_accessor :content_type

      # Specify the from address for the message.
      adv_attr_accessor :from

      # Specify the address (if different than the "from" address) to direct
      # replies to this message.
      adv_attr_accessor :reply_to

      # Specify additional headers to be added to the message.
      adv_attr_accessor :headers

      # Specify the order in which parts should be sorted, based on content-type.
      # This defaults to the value for the +default_implicit_parts_order+.
      adv_attr_accessor :implicit_parts_order

      # Defaults to "1.0", but may be explicitly given if needed.
      adv_attr_accessor :mime_version

      # The recipient addresses for the message, either as a string (for a single
      # address) or an array (for multiple addresses).
      adv_attr_accessor :recipients

      # The date on which the message was sent. If not set (the default), the
      # header will be set by the delivery agent.
      adv_attr_accessor :sent_on

      # Specify the subject of the message.
      adv_attr_accessor :subject

      # Specify the template name to use for current message. This is the "base"
      # template name, without the extension or directory, and may be used to
      # have multiple mailer methods share the same template.
      adv_attr_accessor :template

      # Override the mailer name, which defaults to an inflected version of the
      # mailer's class name. If you want to use a template in a non-standard
      # location, you can use this to specify that location.
      adv_attr_accessor :mailer_name

      # Define the body of the message. This is either a Hash (in which case it
      # specifies the variables to pass to the template when it is rendered),
      # or a string, in which case it specifies the actual text of the message.
      adv_attr_accessor :body

      # Alias controller_path to mailer_name so render :partial in views work.
      alias :controller_path :mailer_name
      
    end

    module ClassMethods

      # Deliver the given mail object directly. This can be used to deliver
      # a preconstructed mail object, like:
      #
      #   email = MyMailer.create_some_mail(parameters)
      #   email.set_some_obscure_header "frobnicate"
      #   MyMailer.deliver(email)
      def deliver(mail)
        return if @mail_was_called
        raise "no mail object available for delivery!" unless mail

        mail.register_for_delivery_notification(self)

        mail.delivery_method delivery_methods[delivery_method],
                             delivery_settings[delivery_method]

        mail.raise_delivery_errors = raise_delivery_errors
        mail.perform_deliveries = perform_deliveries
        mail.deliver
        mail
      end

      def respond_to?(method_symbol, include_private = false) #:nodoc:
        matches_dynamic_method?(method_symbol) || super
      end

      def method_missing(method_symbol, *parameters) #:nodoc:
        if match = matches_dynamic_method?(method_symbol)
          case match[1]
            when 'create'  then new(match[2], *parameters).message
            when 'deliver' then new(match[2], *parameters).deliver!
            when 'new'     then nil
            else super
          end
        else
          super
        end
      end

    private

      def matches_dynamic_method?(method_name) #:nodoc:
        method_name = method_name.to_s
        /^(create|deliver)_([_a-z]\w*)/.match(method_name) || /^(new)$/.match(method_name)
      end
    end

    def initialize(*)
      super()
      @mail_was_called = false
    end

    # Delivers a Mail object. By default, it delivers the cached mail
    # object (from the <tt>create!</tt> method). If no cached mail object exists, and
    # no alternate has been given as the parameter, this will fail.
    def deliver!(mail = @message)
      self.class.deliver(mail)
    end

    def render(*args)
      options = args.last.is_a?(Hash) ? args.last : {}
      if options[:body]
        ActiveSupport::Deprecation.warn(':body in render deprecated. Please call body ' <<
                                        'with a hash instead', caller[0,1])

        body options.delete(:body)
      end

      super
    end

    def process(method_name, *args)
      initialize_defaults(method_name)
      super
      unless @mail_was_called
        create_parts
        create_mail
      end
      @message
    end

    # Add a part to a multipart message, with the given content-type. The
    # part itself is yielded to the block so that other properties (charset,
    # body, headers, etc.) can be set on it.
    def part(params)
      params = {:content_type => params} if String === params

      if custom_headers = params.delete(:headers)
        params.merge!(custom_headers)
      end

      part = Mail::Part.new(params)

      yield part if block_given?
      @parts << part
    end

    # Add an attachment to a multipart message. This is simply a part with the
    # content-disposition set to "attachment".
    def attachment(params, &block)
      params = { :content_type => params } if String === params

      params[:content] ||= params.delete(:data) || params.delete(:body)

      if params[:filename]
        params = normalize_file_hash(params)
      else
        params = normalize_nonfile_hash(params)
      end

      part(params, &block)
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
    def render_message(object)
      case object
      when String
        render_to_body(:template => object)
      else
        render_to_body(object)
      end
    end

  private
    
    def normalize_nonfile_hash(params)
      content_disposition = "attachment;"
      
      mime_type = params.delete(:mime_type)
      
      if content_type = params.delete(:content_type)
        content_type = "#{mime_type || content_type};"
      end

      params[:body] = params.delete(:data) if params[:data]
      
      { :content_type => content_type,
        :content_disposition => content_disposition }.merge(params)
    end
    
    def normalize_file_hash(params)
      filename = File.basename(params.delete(:filename))
      content_disposition = "attachment; filename=\"#{File.basename(filename)}\""
      
      mime_type = params.delete(:mime_type)
      
      if (content_type = params.delete(:content_type)) && (content_type !~ /filename=/)
        content_type = "#{mime_type || content_type}; filename=\"#{filename}\""
      end
      
      params[:body] = params.delete(:data) if params[:data]
      
      { :content_type => content_type,
        :content_disposition => content_disposition }.merge(params)
    end
    
    def create_mail #:nodoc:
      m = @message

      m.subject,     = quote_any_if_necessary(charset, subject)
      m.to, m.from   = quote_any_address_if_necessary(charset, recipients, from)
      m.bcc          = quote_address_if_necessary(bcc, charset) unless bcc.nil?
      m.cc           = quote_address_if_necessary(cc, charset) unless cc.nil?
      m.reply_to     = quote_address_if_necessary(reply_to, charset) unless reply_to.nil?
      m.mime_version = mime_version unless mime_version.nil?
      m.date         = sent_on.to_time rescue sent_on if sent_on

      @headers.each { |k, v| m[k] = v }

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
    
    # Set up the default values for the various instance variables of this
    # mailer. Subclasses may override this method to provide different
    # defaults.
    def initialize_defaults(method_name) #:nodoc:
      @charset              ||= self.class.default_charset.dup
      @content_type         ||= self.class.default_content_type.dup
      @implicit_parts_order ||= self.class.default_implicit_parts_order.dup
      @mime_version         ||= self.class.default_mime_version.dup if self.class.default_mime_version

      @mailer_name ||= self.class.mailer_name.dup
      @template    ||= method_name

      @parts   ||= []
      @headers ||= {}
      @sent_on ||= Time.now
      @body ||= {}
    end

    def create_parts #:nodoc:
      if String === @body
        self.response_body = @body
      elsif @body.is_a?(Hash) && !@body.empty?
        @body.each { |k, v| instance_variable_set(:"@#{k}", v) }
      end

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
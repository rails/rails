require 'active_support/concern'
require 'active_support/core_ext/object/try'
require 'active_support/core_ext/object/blank'

module ActionMailer
  module OldApi #:nodoc:
    extend ActiveSupport::Concern

    included do
      extend ActionMailer::AdvAttrAccessor
      self.protected_instance_variables.concat %w(@parts @mail_was_called @headers)

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

      # Specify the order in which parts should be sorted, based on content-type.
      # This defaults to the value for the +default_implicit_parts_order+.
      adv_attr_accessor :implicit_parts_order

      # Defaults to "1.0", but may be explicitly given if needed.
      adv_attr_accessor :mime_version

      # The recipient addresses for the message, either as a string (for a single
      # address) or an array (for multiple addresses).
      adv_attr_accessor :recipients, "Please pass :to as hash key to mail() instead"

      # The date on which the message was sent. If not set (the default), the
      # header will be set by the delivery agent.
      adv_attr_accessor :sent_on, "Please pass :date as hash key to mail() instead"

      # Specify the subject of the message.
      adv_attr_accessor :subject

      # Specify the template name to use for current message. This is the "base"
      # template name, without the extension or directory, and may be used to
      # have multiple mailer methods share the same template.
      adv_attr_accessor :template, "Please pass :template_name or :template_path as hash key to mail() instead"

      # Define the body of the message. This is either a Hash (in which case it
      # specifies the variables to pass to the template when it is rendered),
      # or a string, in which case it specifies the actual text of the message.
      adv_attr_accessor :body
    end

    def process(method_name, *args)
      initialize_defaults(method_name)
      super
      unless @mail_was_called
        create_parts
        create_mail
      end
      @_message
    end

    # Add a part to a multipart message, with the given content-type. The
    # part itself is yielded to the block so that other properties (charset,
    # body, headers, etc.) can be set on it.
    def part(params)
      ActiveSupport::Deprecation.warn "part() is deprecated and will be removed in future versions. " <<
        "Please pass a block to mail() instead."
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
      ActiveSupport::Deprecation.warn "attachment() is deprecated and will be removed in future versions. " <<
        "Please use the attachments[] API instead."
      params = { :content_type => params } if String === params

      params[:content] ||= params.delete(:data) || params.delete(:body)

      if params[:filename]
        params = normalize_file_hash(params)
      else
        params = normalize_nonfile_hash(params)
      end

      part(params, &block)
    end

  protected

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

    def create_mail
      m = @_message

      set_fields!({:subject => @subject, :to => @recipients, :from => @from,
                   :bcc => @bcc, :cc => @cc, :reply_to => @reply_to}, @charset)

      m.mime_version = @mime_version    if @mime_version
      m.date         = @sent_on.to_time rescue @sent_on if @sent_on

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

      wrap_delivery_behavior!
      m.content_transfer_encoding = '8bit' unless m.body.only_us_ascii?

      @_message
    end

    # Set up the default values for the various instance variables of this
    # mailer. Subclasses may override this method to provide different
    # defaults.
    def initialize_defaults(method_name)
      @charset              ||= self.class.default[:charset].try(:dup)
      @content_type         ||= self.class.default[:content_type].try(:dup)
      @implicit_parts_order ||= self.class.default[:parts_order].try(:dup)
      @mime_version         ||= self.class.default[:mime_version].try(:dup)

      @cc, @bcc, @reply_to, @subject, @from, @recipients = nil, nil, nil, nil, nil, nil

      @mailer_name   ||= self.class.mailer_name.dup
      @template      ||= method_name
      @mail_was_called = false

      @parts   ||= []
      @headers ||= {}
      @sent_on ||= Time.now
      @body ||= {}
    end

    def create_parts
      if String === @body
        @parts.unshift create_inline_part(@body)
      elsif @parts.empty? || @parts.all? { |p| p.content_disposition =~ /^attachment/ }
        lookup_context.find_all(@template, [@mailer_name]).each do |template|
          self.formats = template.formats
          @parts << create_inline_part(render(:template => template), template.mime_type)
        end

        if @parts.size > 1
          @content_type = "multipart/alternative" if @content_type !~ /^multipart/
        end

        # If this is a multipart e-mail add the mime_version if it is not
        # already set.
        @mime_version ||= "1.0" unless @parts.empty?
      end
    end

    def create_inline_part(body, mime_type=nil)
      ct = mime_type || "text/plain"
      main_type, sub_type = split_content_type(ct.to_s)

      Mail::Part.new(
        :content_type => [main_type, sub_type, {:charset => charset}],
        :content_disposition => "inline",
        :body => body
      )
    end

    def set_fields!(headers, charset) #:nodoc:
      m = @_message
      m.charset = charset
      m.subject  ||= headers.delete(:subject)  if headers[:subject]
      m.to       ||= headers.delete(:to)       if headers[:to]
      m.from     ||= headers.delete(:from)     if headers[:from]
      m.cc       ||= headers.delete(:cc)       if headers[:cc]
      m.bcc      ||= headers.delete(:bcc)      if headers[:bcc]
      m.reply_to ||= headers.delete(:reply_to) if headers[:reply_to]
    end

    def split_content_type(ct)
      ct.to_s.split("/")
    end

    def parse_content_type
      if @content_type.blank?
        [ nil, {} ]
      else
        ctype, *attrs = @content_type.split(/;\s*/)
        attrs = Hash[attrs.map { |attr| attr.split(/=/, 2) }]
        [ctype, {"charset" => @charset}.merge!(attrs)]
      end
    end
  end
end

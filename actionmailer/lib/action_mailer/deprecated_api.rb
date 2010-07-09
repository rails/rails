module ActionMailer
  # This is the API which is deprecated and is going to be removed on Rails 3.1 release.
  # Part of the old API will be deprecated after 3.1, for a smoother deprecation process.
  # Check those in OldApi instead.
  module DeprecatedApi #:nodoc:
    extend ActiveSupport::Concern

    included do
      [:charset, :content_type, :mime_version, :implicit_parts_order].each do |method|
        class_eval <<-FILE, __FILE__, __LINE__ + 1
          def self.default_#{method}
            @@default_#{method}
          end

          def self.default_#{method}=(value)
            ActiveSupport::Deprecation.warn "ActionMailer::Base.default_#{method}=value is deprecated, " <<
              "use default :#{method} => value instead"
            @@default_#{method} = value
          end

          @@default_#{method} = nil
        FILE
      end
    end

    module ClassMethods
      # Deliver the given mail object directly. This can be used to deliver
      # a preconstructed mail object, like:
      #
      #   email = MyMailer.create_some_mail(parameters)
      #   email.set_some_obscure_header "frobnicate"
      #   MyMailer.deliver(email)
      def deliver(mail, show_warning=true)
        if show_warning
          ActiveSupport::Deprecation.warn "#{self}.deliver is deprecated, call " <<
            "deliver in the mailer instance instead", caller[0,2]
        end

        raise "no mail object available for delivery!" unless mail
        wrap_delivery_behavior(mail)
        mail.deliver
        mail
      end

      def template_root
        self.view_paths && self.view_paths.first
      end

      def template_root=(root)
        ActiveSupport::Deprecation.warn "template_root= is deprecated, use prepend_view_path instead", caller[0,2]
        self.view_paths = ActionView::Base.process_view_paths(root)
      end

      def respond_to?(method_symbol, include_private = false)
        matches_dynamic_method?(method_symbol) || super
      end

      def method_missing(method_symbol, *parameters)
        if match = matches_dynamic_method?(method_symbol)
          case match[1]
            when 'create'
              ActiveSupport::Deprecation.warn "#{self}.create_#{match[2]} is deprecated, " <<
                "use #{self}.#{match[2]} instead", caller[0,2]
              new(match[2], *parameters).message
            when 'deliver'
              ActiveSupport::Deprecation.warn "#{self}.deliver_#{match[2]} is deprecated, " <<
                "use #{self}.#{match[2]}.deliver instead", caller[0,2]
              new(match[2], *parameters).message.deliver
            else super
          end
        else
          super
        end
      end

    private

      def matches_dynamic_method?(method_name)
        method_name = method_name.to_s
        /^(create|deliver)_([_a-z]\w*)/.match(method_name) || /^(new)$/.match(method_name)
      end
    end

    # Delivers a Mail object. By default, it delivers the cached mail
    # object (from the <tt>create!</tt> method). If no cached mail object exists, and
    # no alternate has been given as the parameter, this will fail.
    def deliver!(mail = @_message)
      ActiveSupport::Deprecation.warn "Calling deliver in the AM::Base object is deprecated, " <<
        "please call deliver in the Mail instance", caller[0,2]
      self.class.deliver(mail, false)
    end
    alias :deliver :deliver!

    def render(*args)
      options = args.last.is_a?(Hash) ? args.last : {}

      if options[:body].is_a?(Hash)
        ActiveSupport::Deprecation.warn(':body in render deprecated. Please use instance ' <<
                                        'variables as assigns instead', caller[0,1])

        options[:body].each { |k,v| instance_variable_set(:"@#{k}", v) }
      end
      super
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
    def render_message(*args)
      ActiveSupport::Deprecation.warn "render_message is deprecated, use render instead", caller[0,2]
      render(*args)
    end

  private

    def initialize_defaults(*)
      @charset              ||= self.class.default_charset.try(:dup)
      @content_type         ||= self.class.default_content_type.try(:dup)
      @implicit_parts_order ||= self.class.default_implicit_parts_order.try(:dup)
      @mime_version         ||= self.class.default_mime_version.try(:dup)
      super
    end

    def create_parts
      if @body.is_a?(Hash) && !@body.empty?
        ActiveSupport::Deprecation.warn "Giving a hash to body is deprecated, please use instance variables instead", caller[0,2]
        @body.each { |k, v| instance_variable_set(:"@#{k}", v) }
      end
      super
    end

  end
end

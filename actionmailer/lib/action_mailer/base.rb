module ActionMailer #:nodoc:
  # Action Mailer allows you to send email from your application using a mailer model and views.
  #
  #
  # = Mailer Models
  #
  # To use Action Mailer, you need to create a mailer model.
  #
  #   $ script/generate mailer Notifier
  #
  # The generated model inherits from ActionMailer::Base. Emails are defined by creating methods within the model which are then
  # used to set variables to be used in the mail template, to change options on the mail, or
  # to add attachments.
  #
  # Examples:
  #
  #  class Notifier < ActionMailer::Base
  #    def signup_notification(recipient)
  #      recipients recipient.email_address_with_name
  #      bcc        ["bcc@example.com", "Order Watcher <watcher@example.com>"]
  #      from       "system@example.com"
  #      subject    "New account information"
  #      body       :account => recipient
  #    end
  #  end
  #
  # Mailer methods have the following configuration methods available.
  #
  # * <tt>recipients</tt> - Takes one or more email addresses. These addresses are where your email will be delivered to. Sets the <tt>To:</tt> header.
  # * <tt>subject</tt> - The subject of your email. Sets the <tt>Subject:</tt> header.
  # * <tt>from</tt> - Who the email you are sending is from. Sets the <tt>From:</tt> header.
  # * <tt>cc</tt> - Takes one or more email addresses. These addresses will receive a carbon copy of your email. Sets the <tt>Cc:</tt> header.
  # * <tt>bcc</tt> - Takes one or more email addresses. These addresses will receive a blind carbon copy of your email. Sets the <tt>Bcc:</tt> header.
  # * <tt>reply_to</tt> - Takes one or more email addresses. These addresses will be listed as the default recipients when replying to your email. Sets the <tt>Reply-To:</tt> header.
  # * <tt>sent_on</tt> - The date on which the message was sent. If not set, the header wil be set by the delivery agent.
  # * <tt>content_type</tt> - Specify the content type of the message. Defaults to <tt>text/plain</tt>.
  # * <tt>headers</tt> - Specify additional headers to be set for the message, e.g. <tt>headers 'X-Mail-Count' => 107370</tt>.
  #
  # When a <tt>headers 'return-path'</tt> is specified, that value will be used as the 'envelope from'
  # address. Setting this is useful when you want delivery notifications sent to a different address than
  # the one in <tt>from</tt>.
  #
  # The <tt>body</tt> method has special behavior. It takes a hash which generates an instance variable
  # named after each key in the hash containing the value that that key points to.
  #
  # So, for example, <tt>body :account => recipient</tt> would result
  # in an instance variable <tt>@account</tt> with the value of <tt>recipient</tt> being accessible in the
  # view.
  #
  #
  # = Mailer views
  #
  # Like Action Controller, each mailer class has a corresponding view directory
  # in which each method of the class looks for a template with its name.
  # To define a template to be used with a mailing, create an <tt>.erb</tt> file with the same name as the method
  # in your mailer model. For example, in the mailer defined above, the template at
  # <tt>app/views/notifier/signup_notification.erb</tt> would be used to generate the email.
  #
  # Variables defined in the model are accessible as instance variables in the view.
  #
  # Emails by default are sent in plain text, so a sample view for our model example might look like this:
  #
  #   Hi <%= @account.name %>,
  #   Thanks for joining our service! Please check back often.
  #
  # You can even use Action Pack helpers in these views. For example:
  #
  #   You got a new note!
  #   <%= truncate(note.body, 25) %>
  #
  #
  # = Generating URLs
  #
  # URLs can be generated in mailer views using <tt>url_for</tt> or named routes.
  # Unlike controllers from Action Pack, the mailer instance doesn't have any context about the incoming request,
  # so you'll need to provide all of the details needed to generate a URL.
  #
  # When using <tt>url_for</tt> you'll need to provide the <tt>:host</tt>, <tt>:controller</tt>, and <tt>:action</tt>:
  #
  #   <%= url_for(:host => "example.com", :controller => "welcome", :action => "greeting") %>
  #
  # When using named routes you only need to supply the <tt>:host</tt>:
  #
  #   <%= users_url(:host => "example.com") %>
  #
  # You will want to avoid using the <tt>name_of_route_path</tt> form of named routes because it doesn't make sense to
  # generate relative URLs in email messages.
  #
  # It is also possible to set a default host that will be used in all mailers by setting the <tt>:host</tt> option in
  # the <tt>ActionMailer::Base.default_url_options</tt> hash as follows:
  #
  #   ActionMailer::Base.default_url_options[:host] = "example.com"
  #
  # This can also be set as a configuration option in <tt>config/environment.rb</tt>:
  #
  #   config.action_mailer.default_url_options = { :host => "example.com" }
  #
  # If you do decide to set a default <tt>:host</tt> for your mailers you will want to use the
  # <tt>:only_path => false</tt> option when using <tt>url_for</tt>. This will ensure that absolute URLs are generated because
  # the <tt>url_for</tt> view helper will, by default, generate relative URLs when a <tt>:host</tt> option isn't
  # explicitly provided.
  #
  # = Sending mail
  #
  # Once a mailer action and template are defined, you can deliver your message or create it and save it
  # for delivery later:
  #
  #   Notifier.deliver_signup_notification(david) # sends the email
  #   mail = Notifier.create_signup_notification(david)  # => a tmail object
  #   Notifier.deliver(mail)
  #
  # You never instantiate your mailer class. Rather, your delivery instance
  # methods are automatically wrapped in class methods that start with the word
  # <tt>deliver_</tt> followed by the name of the mailer method that you would
  # like to deliver. The <tt>signup_notification</tt> method defined above is
  # delivered by invoking <tt>Notifier.deliver_signup_notification</tt>.
  #
  #
  # = HTML email
  #
  # To send mail as HTML, make sure your view (the <tt>.erb</tt> file) generates HTML and
  # set the content type to html.
  #
  #   class MyMailer < ActionMailer::Base
  #     def signup_notification(recipient)
  #       recipients   recipient.email_address_with_name
  #       subject      "New account information"
  #       from         "system@example.com"
  #       body         :account => recipient
  #       content_type "text/html"
  #     end
  #   end
  #
  #
  # = Multipart email
  #
  # You can explicitly specify multipart messages:
  #
  #   class ApplicationMailer < ActionMailer::Base
  #     def signup_notification(recipient)
  #       recipients      recipient.email_address_with_name
  #       subject         "New account information"
  #       from            "system@example.com"
  #       content_type    "multipart/alternative"
  #
  #       part :content_type => "text/html",
  #         :body => render_message("signup-as-html", :account => recipient)
  #
  #       part "text/plain" do |p|
  #         p.body = render_message("signup-as-plain", :account => recipient)
  #         p.transfer_encoding = "base64"
  #       end
  #     end
  #   end
  #
  # Multipart messages can also be used implicitly because Action Mailer will automatically
  # detect and use multipart templates, where each template is named after the name of the action, followed
  # by the content type. Each such detected template will be added as separate part to the message.
  #
  # For example, if the following templates existed:
  # * signup_notification.text.plain.erb
  # * signup_notification.text.html.erb
  # * signup_notification.text.xml.builder
  # * signup_notification.text.x-yaml.erb
  #
  # Each would be rendered and added as a separate part to the message,
  # with the corresponding content type. The content type for the entire
  # message is automatically set to <tt>multipart/alternative</tt>, which indicates
  # that the email contains multiple different representations of the same email
  # body. The same body hash is passed to each template.
  #
  # Implicit template rendering is not performed if any attachments or parts have been added to the email.
  # This means that you'll have to manually add each part to the email and set the content type of the email
  # to <tt>multipart/alternative</tt>.
  #
  # = Attachments
  #
  # Attachments can be added by using the +attachment+ method.
  #
  # Example:
  #
  #   class ApplicationMailer < ActionMailer::Base
  #     # attachments
  #     def signup_notification(recipient)
  #       recipients      recipient.email_address_with_name
  #       subject         "New account information"
  #       from            "system@example.com"
  #
  #       attachment :content_type => "image/jpeg",
  #         :body => File.read("an-image.jpg")
  #
  #       attachment "application/pdf" do |a|
  #         a.body = generate_your_pdf_here()
  #       end
  #     end
  #   end
  #
  #
  # = Configuration options
  #
  # These options are specified on the class level, like <tt>ActionMailer::Base.template_root = "/my/templates"</tt>
  #
  # * <tt>template_root</tt> - Determines the base from which template references will be made.
  #
  # * <tt>logger</tt> - the logger is used for generating information on the mailing run if available.
  #   Can be set to nil for no logging. Compatible with both Ruby's own Logger and Log4r loggers.
  #
  # * <tt>smtp_settings</tt> - Allows detailed configuration for <tt>:smtp</tt> delivery method:
  #   * <tt>:address</tt> - Allows you to use a remote mail server. Just change it from its default "localhost" setting.
  #   * <tt>:port</tt> - On the off chance that your mail server doesn't run on port 25, you can change it.
  #   * <tt>:domain</tt> - If you need to specify a HELO domain, you can do it here.
  #   * <tt>:user_name</tt> - If your mail server requires authentication, set the username in this setting.
  #   * <tt>:password</tt> - If your mail server requires authentication, set the password in this setting.
  #   * <tt>:authentication</tt> - If your mail server requires authentication, you need to specify the authentication type here.
  #     This is a symbol and one of <tt>:plain</tt>, <tt>:login</tt>, <tt>:cram_md5</tt>.
  #   * <tt>:enable_starttls_auto</tt> - When set to true, detects if STARTTLS is enabled in your SMTP server and starts to use it.
  #     It works only on Ruby >= 1.8.7 and Ruby >= 1.9. Default is true.
  #
  # * <tt>sendmail_settings</tt> - Allows you to override options for the <tt>:sendmail</tt> delivery method.
  #   * <tt>:location</tt> - The location of the sendmail executable. Defaults to <tt>/usr/sbin/sendmail</tt>.
  #   * <tt>:arguments</tt> - The command line arguments. Defaults to <tt>-i -t</tt>.
  #
  # * <tt>raise_delivery_errors</tt> - Whether or not errors should be raised if the email fails to be delivered.
  #
  # * <tt>delivery_method</tt> - Defines a delivery method. Possible values are <tt>:smtp</tt> (default), <tt>:sendmail</tt>, and <tt>:test</tt>.
  #
  # * <tt>perform_deliveries</tt> - Determines whether <tt>deliver_*</tt> methods are actually carried out. By default they are,
  #   but this can be turned off to help functional testing.
  #
  # * <tt>deliveries</tt> - Keeps an array of all the emails sent out through the Action Mailer with <tt>delivery_method :test</tt>. Most useful
  #   for unit and functional testing.
  #
  # * <tt>default_charset</tt> - The default charset used for the body and to encode the subject. Defaults to UTF-8. You can also
  #   pick a different charset from inside a method with +charset+.
  #
  # * <tt>default_content_type</tt> - The default content type used for the main part of the message. Defaults to "text/plain". You
  #   can also pick a different content type from inside a method with +content_type+.
  #
  # * <tt>default_mime_version</tt> - The default mime version used for the message. Defaults to <tt>1.0</tt>. You
  #   can also pick a different value from inside a method with +mime_version+.
  #
  # * <tt>default_implicit_parts_order</tt> - When a message is built implicitly (i.e. multiple parts are assembled from templates
  #   which specify the content type in their filenames) this variable controls how the parts are ordered. Defaults to
  #   <tt>["text/html", "text/enriched", "text/plain"]</tt>. Items that appear first in the array have higher priority in the mail client
  #   and appear last in the mime encoded message. You can also pick a different order from inside a method with
  #   +implicit_parts_order+.
  class Base
    include AdvAttrAccessor, PartContainer, Quoting, Utils
    if Object.const_defined?(:ActionController)
      include ActionController::UrlWriter
      include ActionController::Layout
    end

    private_class_method :new #:nodoc:

    class_inheritable_accessor :view_paths
    self.view_paths = []

    cattr_accessor :logger

    @@smtp_settings = {
      :address              => "localhost",
      :port                 => 25,
      :domain               => 'localhost.localdomain',
      :user_name            => nil,
      :password             => nil,
      :authentication       => nil,
      :enable_starttls_auto => true,
    }
    cattr_accessor :smtp_settings

    @@sendmail_settings = {
      :location       => '/usr/sbin/sendmail',
      :arguments      => '-i -t'
    }
    cattr_accessor :sendmail_settings

    @@raise_delivery_errors = true
    cattr_accessor :raise_delivery_errors

    superclass_delegating_accessor :delivery_method
    self.delivery_method = :smtp

    @@perform_deliveries = true
    cattr_accessor :perform_deliveries

    @@deliveries = []
    cattr_accessor :deliveries

    @@default_charset = "utf-8"
    cattr_accessor :default_charset

    @@default_content_type = "text/plain"
    cattr_accessor :default_content_type

    @@default_mime_version = "1.0"
    cattr_accessor :default_mime_version

    @@default_implicit_parts_order = [ "text/html", "text/enriched", "text/plain" ]
    cattr_accessor :default_implicit_parts_order

    cattr_reader :protected_instance_variables
    @@protected_instance_variables = %w(@body)

    # Specify the BCC addresses for the message
    adv_attr_accessor :bcc

    # Define the body of the message. This is either a Hash (in which case it
    # specifies the variables to pass to the template when it is rendered),
    # or a string, in which case it specifies the actual text of the message.
    adv_attr_accessor :body

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
    def mailer_name(value = nil)
      if value
        self.mailer_name = value
      else
        self.class.mailer_name
      end
    end

    def mailer_name=(value)
      self.class.mailer_name = value
    end

    # The mail object instance referenced by this mailer.
    attr_reader :mail
    attr_reader :template_name, :default_template_name, :action_name

    class << self
      attr_writer :mailer_name

      def mailer_name
        @mailer_name ||= name.underscore
      end

      # for ActionView compatibility
      alias_method :controller_name, :mailer_name
      alias_method :controller_path, :mailer_name

      def respond_to?(method_symbol, include_private = false) #:nodoc:
        matches_dynamic_method?(method_symbol) || super
      end

      def method_missing(method_symbol, *parameters) #:nodoc:
        if match = matches_dynamic_method?(method_symbol)
          case match[1]
            when 'create'  then new(match[2], *parameters).mail
            when 'deliver' then new(match[2], *parameters).deliver!
            when 'new'     then nil
            else super
          end
        else
          super
        end
      end

      # Receives a raw email, parses it into an email object, decodes it,
      # instantiates a new mailer, and passes the email object to the mailer
      # object's +receive+ method. If you want your mailer to be able to
      # process incoming messages, you'll need to implement a +receive+
      # method that accepts the email object as a parameter:
      #
      #   class MyMailer < ActionMailer::Base
      #     def receive(mail)
      #       ...
      #     end
      #   end
      def receive(raw_email)
        logger.info "Received mail:\n #{raw_email}" unless logger.nil?
        mail = TMail::Mail.parse(raw_email)
        mail.base64_decode
        new.receive(mail)
      end

      # Deliver the given mail object directly. This can be used to deliver
      # a preconstructed mail object, like:
      #
      #   email = MyMailer.create_some_mail(parameters)
      #   email.set_some_obscure_header "frobnicate"
      #   MyMailer.deliver(email)
      def deliver(mail)
        new.deliver!(mail)
      end

      def template_root
        self.view_paths && self.view_paths.first
      end

      def template_root=(root)
        self.view_paths = ActionView::Base.process_view_paths(root)
      end

      private
        def matches_dynamic_method?(method_name) #:nodoc:
          method_name = method_name.to_s
          /^(create|deliver)_([_a-z]\w*)/.match(method_name) || /^(new)$/.match(method_name)
        end
    end

    # Instantiate a new mailer object. If +method_name+ is not +nil+, the mailer
    # will be initialized according to the named method. If not, the mailer will
    # remain uninitialized (useful when you only need to invoke the "receive"
    # method, for instance).
    def initialize(method_name=nil, *parameters) #:nodoc:
      create!(method_name, *parameters) if method_name
    end

    # Initialize the mailer via the given +method_name+. The body will be
    # rendered and a new TMail::Mail object created.
    def create!(method_name, *parameters) #:nodoc:
      initialize_defaults(method_name)
      __send__(method_name, *parameters)

      # If an explicit, textual body has not been set, we check assumptions.
      unless String === @body
        # First, we look to see if there are any likely templates that match,
        # which include the content-type in their file name (i.e.,
        # "the_template_file.text.html.erb", etc.). Only do this if parts
        # have not already been specified manually.
        if @parts.empty?
          Dir.glob("#{template_path}/#{@template}.*").each do |path|
            template = template_root["#{mailer_name}/#{File.basename(path)}"]

            # Skip unless template has a multipart format
            next unless template && template.multipart?

            @parts << Part.new(
              :content_type => template.content_type,
              :disposition => "inline",
              :charset => charset,
              :body => render_message(template, @body)
            )
          end
          unless @parts.empty?
            @content_type = "multipart/alternative" if @content_type !~ /^multipart/
            @parts = sort_parts(@parts, @implicit_parts_order)
          end
        end

        # Then, if there were such templates, we check to see if we ought to
        # also render a "normal" template (without the content type). If a
        # normal template exists (or if there were no implicit parts) we render
        # it.
        template_exists = @parts.empty?
        template_exists ||= template_root["#{mailer_name}/#{@template}"]
        @body = render_message(@template, @body) if template_exists

        # Finally, if there are other message parts and a textual body exists,
        # we shift it onto the front of the parts and set the body to nil (so
        # that create_mail doesn't try to render it in addition to the parts).
        if !@parts.empty? && String === @body
          @parts.unshift Part.new(:charset => charset, :body => @body)
          @body = nil
        end
      end

      # If this is a multipart e-mail add the mime_version if it is not
      # already set.
      @mime_version ||= "1.0" if !@parts.empty?

      # build the mail object itself
      @mail = create_mail
    end

    # Delivers a TMail::Mail object. By default, it delivers the cached mail
    # object (from the <tt>create!</tt> method). If no cached mail object exists, and
    # no alternate has been given as the parameter, this will fail.
    def deliver!(mail = @mail)
      raise "no mail object available for delivery!" unless mail
      unless logger.nil?
        logger.info  "Sent mail to #{Array(recipients).join(', ')}"
        logger.debug "\n#{mail.encoded}"
      end

      begin
        __send__("perform_delivery_#{delivery_method}", mail) if perform_deliveries
      rescue Exception => e  # Net::SMTP errors or sendmail pipe errors
        raise e if raise_delivery_errors
      end

      return mail
    end

    private
      # Set up the default values for the various instance variables of this
      # mailer. Subclasses may override this method to provide different
      # defaults.
      def initialize_defaults(method_name)
        @charset ||= @@default_charset.dup
        @content_type ||= @@default_content_type.dup
        @implicit_parts_order ||= @@default_implicit_parts_order.dup
        @template ||= method_name
        @default_template_name = @action_name = @template
        @mailer_name ||= self.class.name.underscore
        @parts ||= []
        @headers ||= {}
        @body ||= {}
        @mime_version = @@default_mime_version.dup if @@default_mime_version
        @sent_on ||= Time.now
      end

      def render_message(method_name, body)
        if method_name.respond_to?(:content_type)
          @current_template_content_type = method_name.content_type
        end
        render :file => method_name, :body => body
      ensure
        @current_template_content_type = nil
      end

      def render(opts)
        body = opts.delete(:body)
        if opts[:file] && (opts[:file] !~ /\// && !opts[:file].respond_to?(:render))
          opts[:file] = "#{mailer_name}/#{opts[:file]}"
        end

        begin
          old_template, @template = @template, initialize_template_class(body)
          layout = respond_to?(:pick_layout, true) ? pick_layout(opts) : false
          @template.render(opts.merge(:layout => layout))
        ensure
          @template = old_template
        end
      end

      def default_template_format
        if @current_template_content_type
          Mime::Type.lookup(@current_template_content_type).to_sym
        else
          :html
        end
      end

      def candidate_for_layout?(options)
        !self.view_paths.find_template(default_template_name, default_template_format).exempt_from_layout?
      rescue ActionView::MissingTemplate
        return true
      end

      def template_root
        self.class.template_root
      end

      def template_root=(root)
        self.class.template_root = root
      end

      def template_path
        "#{template_root}/#{mailer_name}"
      end

      def initialize_template_class(assigns)
        template = ActionView::Base.new(self.class.view_paths, assigns, self)
        template.template_format = default_template_format
        template
      end

      def sort_parts(parts, order = [])
        order = order.collect { |s| s.downcase }

        parts = parts.sort do |a, b|
          a_ct = a.content_type.downcase
          b_ct = b.content_type.downcase

          a_in = order.include? a_ct
          b_in = order.include? b_ct

          s = case
          when a_in && b_in
            order.index(a_ct) <=> order.index(b_ct)
          when a_in
            -1
          when b_in
            1
          else
            a_ct <=> b_ct
          end

          # reverse the ordering because parts that come last are displayed
          # first in mail clients
          (s * -1)
        end

        parts
      end

      def create_mail
        m = TMail::Mail.new

        m.subject,     = quote_any_if_necessary(charset, subject)
        m.to, m.from   = quote_any_address_if_necessary(charset, recipients, from)
        m.bcc          = quote_address_if_necessary(bcc, charset) unless bcc.nil?
        m.cc           = quote_address_if_necessary(cc, charset) unless cc.nil?
        m.reply_to     = quote_address_if_necessary(reply_to, charset) unless reply_to.nil?
        m.mime_version = mime_version unless mime_version.nil?
        m.date         = sent_on.to_time rescue sent_on if sent_on

        headers.each { |k, v| m[k] = v }

        real_content_type, ctype_attrs = parse_content_type

        if @parts.empty?
          m.set_content_type(real_content_type, nil, ctype_attrs)
          m.body = normalize_new_lines(body)
        else
          if String === body
            part = TMail::Mail.new
            part.body = normalize_new_lines(body)
            part.set_content_type(real_content_type, nil, ctype_attrs)
            part.set_content_disposition "inline"
            m.parts << part
          end

          @parts.each do |p|
            part = (TMail::Mail === p ? p : p.to_mail(self))
            m.parts << part
          end

          if real_content_type =~ /multipart/
            ctype_attrs.delete "charset"
            m.set_content_type(real_content_type, nil, ctype_attrs)
          end
        end

        @mail = m
      end

      def perform_delivery_smtp(mail)
        destinations = mail.destinations
        mail.ready_to_send
        sender = (mail['return-path'] && mail['return-path'].spec) || mail['from']

        smtp = Net::SMTP.new(smtp_settings[:address], smtp_settings[:port])
        smtp.enable_starttls_auto if smtp_settings[:enable_starttls_auto] && smtp.respond_to?(:enable_starttls_auto)
        smtp.start(smtp_settings[:domain], smtp_settings[:user_name], smtp_settings[:password],
                   smtp_settings[:authentication]) do |smtp|
          smtp.sendmail(mail.encoded, sender, destinations)
        end
      end

      def perform_delivery_sendmail(mail)
        sendmail_args = sendmail_settings[:arguments]
        sendmail_args += " -f \"#{mail['return-path']}\"" if mail['return-path']
        IO.popen("#{sendmail_settings[:location]} #{sendmail_args}","w+") do |sm|
          sm.print(mail.encoded.gsub(/\r/, ''))
          sm.flush
        end
      end

      def perform_delivery_test(mail)
        deliveries << mail
      end
  end

  Base.class_eval do
    include Helpers
    helper MailHelper
  end
end

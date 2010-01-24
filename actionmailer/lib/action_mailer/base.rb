require 'active_support/core_ext/class'
require 'active_support/core_ext/module/delegation'
require 'mail'
require 'action_mailer/tmail_compat'
require 'action_mailer/collector'

module ActionMailer #:nodoc:
  # Action Mailer allows you to send email from your application using a mailer model and views.
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
  # * <tt>sent_on</tt> - The date on which the message was sent. If not set, the header will be set by the delivery agent.
  # * <tt>content_type</tt> - Specify the content type of the message. Defaults to <tt>text/plain</tt>.
  # * <tt>headers</tt> - Specify additional headers to be set for the message, e.g. <tt>headers 'X-Mail-Count' => 107370</tt>.
  #
  # When a <tt>headers 'return-path'</tt> is specified, that value will be used as the 'envelope from'
  # address. Setting this is useful when you want delivery notifications sent to a different address than
  # the one in <tt>from</tt>.
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
  #   <%= truncate(@note.body, 25) %>
  #
  # If you need to access the subject, from or the recipients in the view, you can do that through mailer object:
  #
  #   You got a new note from <%= mailer.from %>!
  #   <%= truncate(@note.body, 25) %>
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
  #       body            :account => recipient
  #
  #       part :content_type => "text/html",
  #         :data => render_message("signup-as-html")
  #
  #       part "text/plain" do |p|
  #         p.body = render_message("signup-as-plain")
  #         p.content_transfer_encoding = "base64"
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
  # * <tt>file_settings</tt> - Allows you to override options for the <tt>:file</tt> delivery method.
  #   * <tt>:location</tt> - The directory into which emails will be written. Defaults to the application <tt>tmp/mails</tt>.
  #
  # * <tt>raise_delivery_errors</tt> - Whether or not errors should be raised if the email fails to be delivered.
  #
  # * <tt>delivery_method</tt> - Defines a delivery method. Possible values are <tt>:smtp</tt> (default), <tt>:sendmail</tt>, <tt>:test</tt>,
  #   and <tt>:file</tt>. Or you may provide a custom delivery method object eg. MyOwnDeliveryMethodClass.new
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
  class Base < AbstractController::Base
    include DeliveryMethods, Quoting
    abstract!

    # TODO Add some sanity tests for the included modules
    include AbstractController::Logger
    include AbstractController::Rendering
    include AbstractController::LocalizedCache
    include AbstractController::Layouts
    include AbstractController::Helpers
    include AbstractController::UrlFor

    helper  ActionMailer::MailHelper

    include ActionMailer::OldApi
    include ActionMailer::DeprecatedApi

    private_class_method :new #:nodoc:

    extlib_inheritable_accessor :default_charset
    self.default_charset = "utf-8"

    extlib_inheritable_accessor :default_content_type
    self.default_content_type = "text/plain"

    extlib_inheritable_accessor :default_mime_version
    self.default_mime_version = "1.0"

    # This specifies the order that the parts of a multipart email will be.  Usually you put
    # text/plain at the top so someone without a MIME capable email reader can read the plain
    # text of your email first.
    #
    # Any content type that is not listed here will be inserted in the order you add them to
    # the email after the content types you list here.
    extlib_inheritable_accessor :default_implicit_parts_order
    self.default_implicit_parts_order = [ "text/plain", "text/enriched", "text/html" ]

    class << self
      def mailer_name
        @mailer_name ||= name.underscore
      end
      attr_writer :mailer_name
      alias :controller_path :mailer_name

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
      def receive(raw_mail)
        ActiveSupport::Notifications.instrument("action_mailer.receive") do |payload|
          mail = Mail.new(raw_mail)
          set_payload_for_mail(payload, mail)
          new.receive(mail)
        end
      end

      # TODO The delivery should happen inside the instrument block
      def delivered_email(mail)
        ActiveSupport::Notifications.instrument("action_mailer.deliver") do |payload|
          self.set_payload_for_mail(payload, mail)
        end
      end

      def respond_to?(method, *args) #:nodoc:
        super || action_methods.include?(method.to_s)
      end

    protected

      def set_payload_for_mail(payload, mail) #:nodoc:
        payload[:mailer]     = self.name
        payload[:message_id] = mail.message_id
        payload[:subject]    = mail.subject
        payload[:to]         = mail.to
        payload[:from]       = mail.from
        payload[:bcc]        = mail.bcc if mail.bcc.present?
        payload[:cc]         = mail.cc  if mail.cc.present?
        payload[:date]       = mail.date
        payload[:mail]       = mail.encoded
      end

      def method_missing(method, *args) #:nodoc:
        if action_methods.include?(method.to_s)
          new(method, *args).message
        else
          super
        end
      end
    end

    attr_internal :message

    # Instantiate a new mailer object. If +method_name+ is not +nil+, the mailer
    # will be initialized according to the named method. If not, the mailer will
    # remain uninitialized (useful when you only need to invoke the "receive"
    # method, for instance).
    def initialize(method_name=nil, *args)
      super()
      @_message = Mail.new
      process(method_name, *args) if method_name
    end

    def headers(args=nil)
      if args
        ActiveSupport::Deprecation.warn "headers(Hash) is deprecated, please do headers[key] = value instead", caller[0,2]
        @headers = args
      else
        @_message
      end
    end

    def attachments
      @_message.attachments
    end

    def mail(headers={}, &block)
      # Guard flag to prevent both the old and the new API from firing
      # Should be removed when old API is removed
      @mail_was_called = true
      m = @_message

      # Give preference to headers and fallback to the ones set in mail
      content_type = headers[:content_type] || m.content_type
      charset      = headers[:charset]      || m.charset      || self.class.default_charset.dup
      mime_version = headers[:mime_version] || m.mime_version || self.class.default_mime_version.dup

      # Set subjects and fields quotings
      headers[:subject] ||= default_subject
      quote_fields!(headers, charset)

      # Render the templates and blocks
      responses, sort_order = collect_responses_and_sort_order(headers, &block)
      content_type ||= create_parts_from_responses(m, responses, charset)

      # Tidy up content type, charset, mime version and sort order
      m.content_type = content_type
      m.charset      = charset
      m.mime_version = mime_version
      sort_order     = headers[:parts_order] || sort_order || self.class.default_implicit_parts_order.dup

      if m.multipart?
        m.body.set_sort_order(sort_order)
        m.body.sort_parts!
      end

      # Finaly set delivery behavior configured in class
      wrap_delivery_behavior!(headers[:delivery_method])
      m
    end

  protected

    def default_subject #:nodoc:
      mailer_scope = self.class.mailer_name.gsub('/', '.')
      I18n.t(:subject, :scope => [:actionmailer, mailer_scope, action_name], :default => action_name.humanize)
    end

    # TODO: Move this into Mail
    def quote_fields!(headers, charset) #:nodoc:
      m = @_message
      m.subject  ||= quote_if_necessary(headers[:subject], charset)          if headers[:subject]
      m.to       ||= quote_address_if_necessary(headers[:to], charset)       if headers[:to]
      m.from     ||= quote_address_if_necessary(headers[:from], charset)     if headers[:from]
      m.cc       ||= quote_address_if_necessary(headers[:cc], charset)       if headers[:cc]
      m.bcc      ||= quote_address_if_necessary(headers[:bcc], charset)      if headers[:bcc]
      m.reply_to ||= quote_address_if_necessary(headers[:reply_to], charset) if headers[:reply_to]
      m.date     ||= headers[:date]                                          if headers[:date]
    end

    def collect_responses_and_sort_order(headers) #:nodoc:
      responses, sort_order = [], nil

      if block_given?
        collector = ActionMailer::Collector.new(self) { render(action_name) }
        yield(collector)
        sort_order = collector.responses.map { |r| r[:content_type] }
        responses  = collector.responses
      elsif headers[:body]
        responses << {
          :body => headers[:body],
          :content_type => self.class.default_content_type.dup
        }
      else
        each_template do |template|
          responses << {
            :body => render_to_body(:_template => template),
            :content_type => template.mime_type.to_s
          }
        end
      end

      [responses, sort_order]
    end

    def each_template(&block) #:nodoc:
      self.class.view_paths.each do |load_paths|
        templates = load_paths.find_all(action_name, {}, self.class.mailer_name)
        unless templates.empty?
          templates.each(&block)
          return
        end
      end
    end

    def create_parts_from_responses(m, responses, charset) #:nodoc:
      if responses.size == 1 && !m.has_attachments?
        m.body = responses[0][:body]
        return responses[0][:content_type]
      elsif responses.size > 1 && m.has_attachments? 
        container = Mail::Part.new
        container.content_type = "multipart/alternate"
        responses.each { |r| insert_part(container, r, charset) }
        m.add_part(container)
      else
        responses.each { |r| insert_part(m, r, charset) }
      end

      m.has_attachments? ? "multipart/mixed" : "multipart/alternate"
    end

    def insert_part(container, response, charset) #:nodoc:
      response[:charset] ||= charset
      part = Mail::Part.new(response)
      container.add_part(part)
    end

  end
end

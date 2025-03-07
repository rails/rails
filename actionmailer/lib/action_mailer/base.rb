# frozen_string_literal: true

require "mail"
require "action_mailer/collector"
require "active_support/core_ext/string/inflections"
require "active_support/core_ext/hash/except"
require "active_support/core_ext/module/anonymous"

require "action_mailer/log_subscriber"
require "action_mailer/rescuable"

module ActionMailer
  # = Action Mailer \Base
  #
  # Action Mailer allows you to send email from your application using a mailer model and views.
  #
  # == Mailer Models
  #
  # To use Action Mailer, you need to create a mailer model.
  #
  #   $ bin/rails generate mailer Notifier
  #
  # The generated model inherits from <tt>ApplicationMailer</tt> which in turn
  # inherits from +ActionMailer::Base+. A mailer model defines methods
  # used to generate an email message. In these methods, you can set up variables to be used in
  # the mailer views, options on the mail itself such as the <tt>:from</tt> address, and attachments.
  #
  #   class ApplicationMailer < ActionMailer::Base
  #     default from: 'from@example.com'
  #     layout 'mailer'
  #   end
  #
  #   class NotifierMailer < ApplicationMailer
  #     default from: 'no-reply@example.com',
  #             return_path: 'system@example.com'
  #
  #     def welcome(recipient)
  #       @account = recipient
  #       mail(to: recipient.email_address_with_name,
  #            bcc: ["bcc@example.com", "Order Watcher <watcher@example.com>"])
  #     end
  #   end
  #
  # Within the mailer method, you have access to the following methods:
  #
  # * <tt>attachments[]=</tt> - Allows you to add attachments to your email in an intuitive
  #   manner; <tt>attachments['filename.png'] = File.read('path/to/filename.png')</tt>
  #
  # * <tt>attachments.inline[]=</tt> - Allows you to add an inline attachment to your email
  #   in the same manner as <tt>attachments[]=</tt>
  #
  # * <tt>headers[]=</tt> - Allows you to specify any header field in your email such
  #   as <tt>headers['X-No-Spam'] = 'True'</tt>. Note that declaring a header multiple times
  #   will add many fields of the same name. Read #headers doc for more information.
  #
  # * <tt>headers(hash)</tt> - Allows you to specify multiple headers in your email such
  #   as <tt>headers({'X-No-Spam' => 'True', 'In-Reply-To' => '1234@message.id'})</tt>
  #
  # * <tt>mail</tt> - Allows you to specify email to be sent.
  #
  # The hash passed to the mail method allows you to specify any header that a +Mail::Message+
  # will accept (any valid email header including optional fields).
  #
  # The +mail+ method, if not passed a block, will inspect your views and send all the views with
  # the same name as the method, so the above action would send the +welcome.text.erb+ view
  # file as well as the +welcome.html.erb+ view file in a +multipart/alternative+ email.
  #
  # If you want to explicitly render only certain templates, pass a block:
  #
  #   mail(to: user.email) do |format|
  #     format.text
  #     format.html
  #   end
  #
  # The block syntax is also useful in providing information specific to a part:
  #
  #   mail(to: user.email) do |format|
  #     format.text(content_transfer_encoding: "base64")
  #     format.html
  #   end
  #
  # Or even to render a special view:
  #
  #   mail(to: user.email) do |format|
  #     format.text
  #     format.html { render "some_other_template" }
  #   end
  #
  # == Mailer views
  #
  # Like Action Controller, each mailer class has a corresponding view directory in which each
  # method of the class looks for a template with its name.
  #
  # To define a template to be used with a mailer, create an <tt>.erb</tt> file with the same
  # name as the method in your mailer model. For example, in the mailer defined above, the template at
  # <tt>app/views/notifier_mailer/welcome.text.erb</tt> would be used to generate the email.
  #
  # Variables defined in the methods of your mailer model are accessible as instance variables in their
  # corresponding view.
  #
  # Emails by default are sent in plain text, so a sample view for our model example might look like this:
  #
  #   Hi <%= @account.name %>,
  #   Thanks for joining our service! Please check back often.
  #
  # You can even use Action View helpers in these views. For example:
  #
  #   You got a new note!
  #   <%= truncate(@note.body, length: 25) %>
  #
  # If you need to access the subject, from, or the recipients in the view, you can do that through message object:
  #
  #   You got a new note from <%= message.from %>!
  #   <%= truncate(@note.body, length: 25) %>
  #
  #
  # == Generating URLs
  #
  # URLs can be generated in mailer views using <tt>url_for</tt> or named routes. Unlike controllers from
  # Action Pack, the mailer instance doesn't have any context about the incoming request, so you'll need
  # to provide all of the details needed to generate a URL.
  #
  # When using <tt>url_for</tt> you'll need to provide the <tt>:host</tt>, <tt>:controller</tt>, and <tt>:action</tt>:
  #
  #   <%= url_for(host: "example.com", controller: "welcome", action: "greeting") %>
  #
  # When using named routes you only need to supply the <tt>:host</tt>:
  #
  #   <%= users_url(host: "example.com") %>
  #
  # You should use the <tt>named_route_url</tt> style (which generates absolute URLs) and avoid using the
  # <tt>named_route_path</tt> style (which generates relative URLs), since clients reading the mail will
  # have no concept of a current URL from which to determine a relative path.
  #
  # It is also possible to set a default host that will be used in all mailers by setting the <tt>:host</tt>
  # option as a configuration option in <tt>config/application.rb</tt>:
  #
  #   config.action_mailer.default_url_options = { host: "example.com" }
  #
  # You can also define a <tt>default_url_options</tt> method on individual mailers to override these
  # default settings per-mailer.
  #
  # By default when <tt>config.force_ssl</tt> is +true+, URLs generated for hosts will use the HTTPS protocol.
  #
  # == Sending mail
  #
  # Once a mailer action and template are defined, you can deliver your message or defer its creation and
  # delivery for later:
  #
  #   NotifierMailer.welcome(User.first).deliver_now # sends the email
  #   mail = NotifierMailer.welcome(User.first)      # => an ActionMailer::MessageDelivery object
  #   mail.deliver_now                               # generates and sends the email now
  #
  # The ActionMailer::MessageDelivery class is a wrapper around a delegate that will call
  # your method to generate the mail. If you want direct access to the delegator, or +Mail::Message+,
  # you can call the <tt>message</tt> method on the ActionMailer::MessageDelivery object.
  #
  #   NotifierMailer.welcome(User.first).message     # => a Mail::Message object
  #
  # Action Mailer is nicely integrated with Active Job so you can generate and send emails in the background
  # (example: outside of the request-response cycle, so the user doesn't have to wait on it):
  #
  #   NotifierMailer.welcome(User.first).deliver_later # enqueue the email sending to Active Job
  #
  # Note that <tt>deliver_later</tt> will execute your method from the background job.
  #
  # You never instantiate your mailer class. Rather, you just call the method you defined on the class itself.
  # All instance methods are expected to return a message object to be sent.
  #
  # == Multipart Emails
  #
  # Multipart messages can also be used implicitly because Action Mailer will automatically detect and use
  # multipart templates, where each template is named after the name of the action, followed by the content
  # type. Each such detected template will be added to the message, as a separate part.
  #
  # For example, if the following templates exist:
  # * signup_notification.text.erb
  # * signup_notification.html.erb
  # * signup_notification.xml.builder
  # * signup_notification.yml.erb
  #
  # Each would be rendered and added as a separate part to the message, with the corresponding content
  # type. The content type for the entire message is automatically set to <tt>multipart/alternative</tt>,
  # which indicates that the email contains multiple different representations of the same email
  # body. The same instance variables defined in the action are passed to all email templates.
  #
  # Implicit template rendering is not performed if any attachments or parts have been added to the email.
  # This means that you'll have to manually add each part to the email and set the content type of the email
  # to <tt>multipart/alternative</tt>.
  #
  # == Attachments
  #
  # Sending attachment in emails is easy:
  #
  #   class NotifierMailer < ApplicationMailer
  #     def welcome(recipient)
  #       attachments['free_book.pdf'] = File.read('path/to/file.pdf')
  #       mail(to: recipient, subject: "New account information")
  #     end
  #   end
  #
  # Which will (if it had both a <tt>welcome.text.erb</tt> and <tt>welcome.html.erb</tt>
  # template in the view directory), send a complete <tt>multipart/mixed</tt> email with two parts,
  # the first part being a <tt>multipart/alternative</tt> with the text and HTML email parts inside,
  # and the second being a <tt>application/pdf</tt> with a Base64 encoded copy of the file.pdf book
  # with the filename +free_book.pdf+.
  #
  # If you need to send attachments with no content, you need to create an empty view for it,
  # or add an empty body parameter like this:
  #
  #     class NotifierMailer < ApplicationMailer
  #       def welcome(recipient)
  #         attachments['free_book.pdf'] = File.read('path/to/file.pdf')
  #         mail(to: recipient, subject: "New account information", body: "")
  #       end
  #     end
  #
  # You can also send attachments with HTML template, in this case you need to add body, attachments,
  # and custom content type like this:
  #
  #     class NotifierMailer < ApplicationMailer
  #       def welcome(recipient)
  #         attachments["free_book.pdf"] = File.read("path/to/file.pdf")
  #         mail(to: recipient,
  #              subject: "New account information",
  #              content_type: "text/html",
  #              body: "<html><body>Hello there</body></html>")
  #       end
  #     end
  #
  # == Inline Attachments
  #
  # You can also specify that a file should be displayed inline with other HTML. This is useful
  # if you want to display a corporate logo or a photo.
  #
  #   class NotifierMailer < ApplicationMailer
  #     def welcome(recipient)
  #       attachments.inline['photo.png'] = File.read('path/to/photo.png')
  #       mail(to: recipient, subject: "Here is what we look like")
  #     end
  #   end
  #
  # And then to reference the image in the view, you create a <tt>welcome.html.erb</tt> file and
  # make a call to +image_tag+ passing in the attachment you want to display and then call
  # +url+ on the attachment to get the relative content id path for the image source:
  #
  #   <h1>Please Don't Cringe</h1>
  #
  #   <%= image_tag attachments['photo.png'].url -%>
  #
  # As we are using Action View's +image_tag+ method, you can pass in any other options you want:
  #
  #   <h1>Please Don't Cringe</h1>
  #
  #   <%= image_tag attachments['photo.png'].url, alt: 'Our Photo', class: 'photo' -%>
  #
  # == Observing and Intercepting Mails
  #
  # Action Mailer provides hooks into the Mail observer and interceptor methods. These allow you to
  # register classes that are called during the mail delivery life cycle.
  #
  # An observer class must implement the <tt>:delivered_email(message)</tt> method which will be
  # called once for every email sent after the email has been sent.
  #
  # An interceptor class must implement the <tt>:delivering_email(message)</tt> method which will be
  # called before the email is sent, allowing you to make modifications to the email before it hits
  # the delivery agents. Your class should make any needed modifications directly to the passed
  # in +Mail::Message+ instance.
  #
  # == Default \Hash
  #
  # Action Mailer provides some intelligent defaults for your emails, these are usually specified in a
  # default method inside the class definition:
  #
  #   class NotifierMailer < ApplicationMailer
  #     default sender: 'system@example.com'
  #   end
  #
  # You can pass in any header value that a +Mail::Message+ accepts. Out of the box,
  # +ActionMailer::Base+ sets the following:
  #
  # * <tt>mime_version: "1.0"</tt>
  # * <tt>charset:      "UTF-8"</tt>
  # * <tt>content_type: "text/plain"</tt>
  # * <tt>parts_order:  [ "text/plain", "text/enriched", "text/html" ]</tt>
  #
  # <tt>parts_order</tt> and <tt>charset</tt> are not actually valid +Mail::Message+ header fields,
  # but Action Mailer translates them appropriately and sets the correct values.
  #
  # As you can pass in any header, you need to either quote the header as a string, or pass it in as
  # an underscored symbol, so the following will work:
  #
  #   class NotifierMailer < ApplicationMailer
  #     default 'Content-Transfer-Encoding' => '7bit',
  #             content_description: 'This is a description'
  #   end
  #
  # Finally, Action Mailer also supports passing <tt>Proc</tt> and <tt>Lambda</tt> objects into the default hash,
  # so you can define methods that evaluate as the message is being generated:
  #
  #   class NotifierMailer < ApplicationMailer
  #     default 'X-Special-Header' => Proc.new { my_method }, to: -> { @inviter.email_address }
  #
  #     private
  #       def my_method
  #         'some complex call'
  #       end
  #   end
  #
  # Note that the proc/lambda is evaluated right at the start of the mail message generation, so if you
  # set something in the default hash using a proc, and then set the same thing inside of your
  # mailer method, it will get overwritten by the mailer method.
  #
  # It is also possible to set these default options that will be used in all mailers through
  # the <tt>default_options=</tt> configuration in <tt>config/application.rb</tt>:
  #
  #    config.action_mailer.default_options = { from: "no-reply@example.org" }
  #
  # == \Callbacks
  #
  # You can specify callbacks using <tt>before_action</tt> and <tt>after_action</tt> for configuring your messages,
  # and using <tt>before_deliver</tt> and <tt>after_deliver</tt> for wrapping the delivery process.
  # For example, when you want to add default inline attachments and log delivery for all messages
  # sent out by a certain mailer class:
  #
  #   class NotifierMailer < ApplicationMailer
  #     before_action :add_inline_attachment!
  #     after_deliver :log_delivery
  #
  #     def welcome
  #       mail
  #     end
  #
  #     private
  #       def add_inline_attachment!
  #         attachments.inline["footer.jpg"] = File.read('/path/to/filename.jpg')
  #       end
  #
  #       def log_delivery
  #         Rails.logger.info "Sent email with message id '#{message.message_id}' at #{Time.current}."
  #       end
  #   end
  #
  # Action callbacks in Action Mailer are implemented using
  # AbstractController::Callbacks, so you can define and configure
  # callbacks in the same manner that you would use callbacks in classes that
  # inherit from ActionController::Base.
  #
  # Note that unless you have a specific reason to do so, you should prefer
  # using <tt>before_action</tt> rather than <tt>after_action</tt> in your
  # Action Mailer classes so that headers are parsed properly.
  #
  # == Rescuing Errors
  #
  # +rescue+ blocks inside of a mailer method cannot rescue errors that occur
  # outside of rendering -- for example, record deserialization errors in a
  # background job, or errors from a third-party mail delivery service.
  #
  # To rescue errors that occur during any part of the mailing process, use
  # {rescue_from}[rdoc-ref:ActiveSupport::Rescuable::ClassMethods#rescue_from]:
  #
  #   class NotifierMailer < ApplicationMailer
  #     rescue_from ActiveJob::DeserializationError do
  #       # ...
  #     end
  #
  #     rescue_from "SomeThirdPartyService::ApiError" do
  #       # ...
  #     end
  #
  #     def notify(recipient)
  #       mail(to: recipient, subject: "Notification")
  #     end
  #   end
  #
  # == Previewing emails
  #
  # You can preview your email templates visually by adding a mailer preview file to the
  # <tt>ActionMailer::Base.preview_paths</tt>. Since most emails do something interesting
  # with database data, you'll need to write some scenarios to load messages with fake data:
  #
  #   class NotifierMailerPreview < ActionMailer::Preview
  #     def welcome
  #       NotifierMailer.welcome(User.first)
  #     end
  #   end
  #
  # Methods must return a +Mail::Message+ object which can be generated by calling the mailer
  # method without the additional <tt>deliver_now</tt> / <tt>deliver_later</tt>. The location of the
  # mailer preview directories can be configured using the <tt>preview_paths</tt> option which has a default
  # of <tt>test/mailers/previews</tt>:
  #
  #   config.action_mailer.preview_paths << "#{Rails.root}/lib/mailer_previews"
  #
  # An overview of all previews is accessible at <tt>http://localhost:3000/rails/mailers</tt>
  # on a running development server instance.
  #
  # Previews can also be intercepted in a similar manner as deliveries can be by registering
  # a preview interceptor that has a <tt>previewing_email</tt> method:
  #
  #   class CssInlineStyler
  #     def self.previewing_email(message)
  #       # inline CSS styles
  #     end
  #   end
  #
  #   config.action_mailer.preview_interceptors :css_inline_styler
  #
  # Note that interceptors need to be registered both with <tt>register_interceptor</tt>
  # and <tt>register_preview_interceptor</tt> if they should operate on both sending and
  # previewing emails.
  #
  # == Configuration options
  #
  # These options are specified on the class level, like
  # <tt>ActionMailer::Base.raise_delivery_errors = true</tt>
  #
  # * <tt>default_options</tt> - You can pass this in at a class level as well as within the class itself as
  #   per the above section.
  #
  # * <tt>logger</tt> - the logger is used for generating information on the mailing run if available.
  #   Can be set to +nil+ for no logging. Compatible with both Ruby's own +Logger+ and Log4r loggers.
  #
  # * <tt>smtp_settings</tt> - Allows detailed configuration for <tt>:smtp</tt> delivery method:
  #   * <tt>:address</tt> - Allows you to use a remote mail server. Just change it from its default
  #     "localhost" setting.
  #   * <tt>:port</tt> - On the off chance that your mail server doesn't run on port 25, you can change it.
  #   * <tt>:domain</tt> - If you need to specify a HELO domain, you can do it here.
  #   * <tt>:user_name</tt> - If your mail server requires authentication, set the username in this setting.
  #   * <tt>:password</tt> - If your mail server requires authentication, set the password in this setting.
  #   * <tt>:authentication</tt> - If your mail server requires authentication, you need to specify the
  #     authentication type here.
  #     This is a symbol and one of <tt>:plain</tt> (will send the password Base64 encoded), <tt>:login</tt> (will
  #     send the password Base64 encoded) or <tt>:cram_md5</tt> (combines a Challenge/Response mechanism to exchange
  #     information and a cryptographic Message Digest 5 algorithm to hash important information)
  #   * <tt>:enable_starttls</tt> - Use STARTTLS when connecting to your SMTP server and fail if unsupported. Defaults
  #     to <tt>false</tt>. Requires at least version 2.7 of the Mail gem.
  #   * <tt>:enable_starttls_auto</tt> - Detects if STARTTLS is enabled in your SMTP server and starts
  #     to use it. Defaults to <tt>true</tt>.
  #   * <tt>:openssl_verify_mode</tt> - When using TLS, you can set how OpenSSL checks the certificate. This is
  #     really useful if you need to validate a self-signed and/or a wildcard certificate. You can use the name
  #     of an OpenSSL verify constant (<tt>'none'</tt> or <tt>'peer'</tt>) or directly the constant
  #     (+OpenSSL::SSL::VERIFY_NONE+ or +OpenSSL::SSL::VERIFY_PEER+).
  #   * <tt>:ssl/:tls</tt> Enables the SMTP connection to use SMTP/TLS (SMTPS: SMTP over direct TLS connection)
  #   * <tt>:open_timeout</tt> Number of seconds to wait while attempting to open a connection.
  #   * <tt>:read_timeout</tt> Number of seconds to wait until timing-out a read(2) call.
  #
  # * <tt>sendmail_settings</tt> - Allows you to override options for the <tt>:sendmail</tt> delivery method.
  #   * <tt>:location</tt> - The location of the sendmail executable. Defaults to <tt>/usr/sbin/sendmail</tt>.
  #   * <tt>:arguments</tt> - The command line arguments. Defaults to <tt>%w[ -i ]</tt> with <tt>-f sender@address</tt>
  #     added automatically before the message is sent.
  #
  # * <tt>file_settings</tt> - Allows you to override options for the <tt>:file</tt> delivery method.
  #   * <tt>:location</tt> - The directory into which emails will be written. Defaults to the application
  #     <tt>tmp/mails</tt>.
  #
  # * <tt>raise_delivery_errors</tt> - Whether or not errors should be raised if the email fails to be delivered.
  #
  # * <tt>delivery_method</tt> - Defines a delivery method. Possible values are <tt>:smtp</tt> (default),
  #   <tt>:sendmail</tt>, <tt>:test</tt>, and <tt>:file</tt>. Or you may provide a custom delivery method
  #   object e.g. +MyOwnDeliveryMethodClass+. See the Mail gem documentation on the interface you need to
  #   implement for a custom delivery agent.
  #
  # * <tt>perform_deliveries</tt> - Determines whether emails are actually sent from Action Mailer when you
  #   call <tt>.deliver</tt> on an email message or on an Action Mailer method. This is on by default but can
  #   be turned off to aid in functional testing.
  #
  # * <tt>deliveries</tt> - Keeps an array of all the emails sent out through the Action Mailer with
  #   <tt>delivery_method :test</tt>. Most useful for unit and functional testing.
  #
  # * <tt>delivery_job</tt> - The job class used with <tt>deliver_later</tt>. Mailers can set this to use a
  #   custom delivery job. Defaults to +ActionMailer::MailDeliveryJob+.
  #
  # * <tt>deliver_later_queue_name</tt> - The queue name used by <tt>deliver_later</tt> with the default
  #   <tt>delivery_job</tt>. Mailers can set this to use a custom queue name.
  class Base < AbstractController::Base
    include Callbacks
    include DeliveryMethods
    include QueuedDelivery
    include Rescuable
    include Parameterized
    include Previews
    include FormBuilder

    abstract!

    include AbstractController::Rendering

    include AbstractController::Logger
    include AbstractController::Helpers
    include AbstractController::Translation
    include AbstractController::AssetPaths
    include AbstractController::Callbacks
    include AbstractController::Caching

    include ActionView::Layouts

    PROTECTED_IVARS = AbstractController::Rendering::DEFAULT_PROTECTED_INSTANCE_VARIABLES + [:@_action_has_layout]

    helper ActionMailer::MailHelper

    class_attribute :default_params, default: {
      mime_version: "1.0",
      charset:      "UTF-8",
      content_type: "text/plain",
      parts_order:  [ "text/plain", "text/enriched", "text/html" ]
    }.freeze

    class << self
      # Register one or more Observers which will be notified when mail is delivered.
      def register_observers(*observers)
        observers.flatten.compact.each { |observer| register_observer(observer) }
      end

      # Unregister one or more previously registered Observers.
      def unregister_observers(*observers)
        observers.flatten.compact.each { |observer| unregister_observer(observer) }
      end

      # Register one or more Interceptors which will be called before mail is sent.
      def register_interceptors(*interceptors)
        interceptors.flatten.compact.each { |interceptor| register_interceptor(interceptor) }
      end

      # Unregister one or more previously registered Interceptors.
      def unregister_interceptors(*interceptors)
        interceptors.flatten.compact.each { |interceptor| unregister_interceptor(interceptor) }
      end

      # Register an Observer which will be notified when mail is delivered.
      # Either a class, string, or symbol can be passed in as the Observer.
      # If a string or symbol is passed in it will be camelized and constantized.
      def register_observer(observer)
        Mail.register_observer(observer_class_for(observer))
      end

      # Unregister a previously registered Observer.
      # Either a class, string, or symbol can be passed in as the Observer.
      # If a string or symbol is passed in it will be camelized and constantized.
      def unregister_observer(observer)
        Mail.unregister_observer(observer_class_for(observer))
      end

      # Register an Interceptor which will be called before mail is sent.
      # Either a class, string, or symbol can be passed in as the Interceptor.
      # If a string or symbol is passed in it will be camelized and constantized.
      def register_interceptor(interceptor)
        Mail.register_interceptor(observer_class_for(interceptor))
      end

      # Unregister a previously registered Interceptor.
      # Either a class, string, or symbol can be passed in as the Interceptor.
      # If a string or symbol is passed in it will be camelized and constantized.
      def unregister_interceptor(interceptor)
        Mail.unregister_interceptor(observer_class_for(interceptor))
      end

      def observer_class_for(value) # :nodoc:
        case value
        when String, Symbol
          value.to_s.camelize.constantize
        else
          value
        end
      end
      private :observer_class_for

      # Returns the name of the current mailer. This method is also being used as a path for a view lookup.
      # If this is an anonymous mailer, this method will return +anonymous+ instead.
      def mailer_name
        @mailer_name ||= anonymous? ? "anonymous" : name.underscore
      end
      # Allows to set the name of current mailer.
      attr_writer :mailer_name
      alias :controller_path :mailer_name

      # Allows to set defaults through app configuration:
      #
      #    config.action_mailer.default_options = { from: "no-reply@example.org" }
      def default(value = nil)
        self.default_params = default_params.merge(value).freeze if value
        default_params
      end
      alias :default_options= :default

      # Wraps an email delivery inside of ActiveSupport::Notifications instrumentation.
      #
      # This method is actually called by the +Mail::Message+ object itself
      # through a callback when you call <tt>:deliver</tt> on the +Mail::Message+,
      # calling +deliver_mail+ directly and passing a +Mail::Message+ will do
      # nothing except tell the logger you sent the email.
      def deliver_mail(mail) # :nodoc:
        ActiveSupport::Notifications.instrument("deliver.action_mailer") do |payload|
          set_payload_for_mail(payload, mail)
          yield # Let Mail do the delivery actions
        end
      end

      # Returns an email in the format "Name <email@example.com>".
      #
      # If the name is a blank string, it returns just the address.
      def email_address_with_name(address, name)
        Mail::Address.new.tap do |builder|
          builder.address = address
          builder.display_name = name.presence
        end.to_s
      end

    private
      def set_payload_for_mail(payload, mail)
        payload[:mail]               = mail.encoded
        payload[:mailer]             = name
        payload[:message_id]         = mail.message_id
        payload[:subject]            = mail.subject
        payload[:to]                 = mail.to
        payload[:from]               = mail.from
        payload[:bcc]                = mail.bcc if mail.bcc.present?
        payload[:cc]                 = mail.cc  if mail.cc.present?
        payload[:date]               = mail.date
        payload[:perform_deliveries] = mail.perform_deliveries
      end

      def method_missing(method_name, ...)
        if action_methods.include?(method_name.name)
          MessageDelivery.new(self, method_name, ...)
        else
          super
        end
      end

      def respond_to_missing?(method, include_all = false)
        action_methods.include?(method.name) || super
      end
    end

    attr_internal :message

    def initialize
      super()
      @_mail_was_called = false
      @_message = Mail.new
    end

    def process(method_name, *args) # :nodoc:
      payload = {
        mailer: self.class.name,
        action: method_name,
        args: args
      }

      ActiveSupport::Notifications.instrument("process.action_mailer", payload) do
        super
        @_message = NullMail.new unless @_mail_was_called
      end
    end
    ruby2_keywords(:process)

    class NullMail # :nodoc:
      def body; "" end
      def header; {} end

      def respond_to?(string, include_all = false)
        true
      end

      def method_missing(...)
        nil
      end
    end

    # Returns the name of the mailer object.
    def mailer_name
      self.class.mailer_name
    end

    # Returns an email in the format "Name <email@example.com>".
    #
    # If the name is a blank string, it returns just the address.
    def email_address_with_name(address, name)
      self.class.email_address_with_name(address, name)
    end

    # Allows you to pass random and unusual headers to the new +Mail::Message+
    # object which will add them to itself.
    #
    #   headers['X-Special-Domain-Specific-Header'] = "SecretValue"
    #
    # You can also pass a hash into headers of header field names and values,
    # which will then be set on the +Mail::Message+ object:
    #
    #   headers 'X-Special-Domain-Specific-Header' => "SecretValue",
    #           'In-Reply-To' => incoming.message_id
    #
    # The resulting +Mail::Message+ will have the following in its header:
    #
    #   X-Special-Domain-Specific-Header: SecretValue
    #
    # Note about replacing already defined headers:
    #
    # * +subject+
    # * +sender+
    # * +from+
    # * +to+
    # * +cc+
    # * +bcc+
    # * +reply-to+
    # * +orig-date+
    # * +message-id+
    # * +references+
    #
    # Fields can only appear once in email headers while other fields such as
    # <tt>X-Anything</tt> can appear multiple times.
    #
    # If you want to replace any header which already exists, first set it to
    # +nil+ in order to reset the value otherwise another field will be added
    # for the same header.
    def headers(args = nil)
      if args
        @_message.headers(args)
      else
        @_message
      end
    end

    # Allows you to add attachments to an email, like so:
    #
    #  mail.attachments['filename.jpg'] = File.read('/path/to/filename.jpg')
    #
    # If you do this, then Mail will take the file name and work out the mime type.
    # It will also set the +Content-Type+, +Content-Disposition+, and +Content-Transfer-Encoding+,
    # and encode the contents of the attachment in Base64.
    #
    # You can also specify overrides if you want by passing a hash instead of a string:
    #
    #  mail.attachments['filename.jpg'] = {mime_type: 'application/gzip',
    #                                      content: File.read('/path/to/filename.jpg')}
    #
    # If you want to use encoding other than Base64 then you will need to pass encoding
    # type along with the pre-encoded content as Mail doesn't know how to decode the
    # data:
    #
    #  file_content = SpecialEncode(File.read('/path/to/filename.jpg'))
    #  mail.attachments['filename.jpg'] = {mime_type: 'application/gzip',
    #                                      encoding: 'SpecialEncoding',
    #                                      content: file_content }
    #
    # You can also search for specific attachments:
    #
    #  # By Filename
    #  mail.attachments['filename.jpg']   # => Mail::Part object or nil
    #
    #  # or by index
    #  mail.attachments[0]                # => Mail::Part (first attachment)
    #
    def attachments
      if @_mail_was_called
        LateAttachmentsProxy.new(@_message.attachments)
      else
        @_message.attachments
      end
    end

    class LateAttachmentsProxy < SimpleDelegator
      def inline; self end
      def []=(_name, _content); _raise_error end

      private
        def _raise_error
          raise RuntimeError, "Can't add attachments after `mail` was called.\n" \
                              "Make sure to use `attachments[]=` before calling `mail`."
        end
    end

    # The main method that creates the message and renders the email templates. There are
    # two ways to call this method, with a block, or without a block.
    #
    # It accepts a headers hash. This hash allows you to specify
    # the most used headers in an email message, these are:
    #
    # * +:subject+ - The subject of the message, if this is omitted, Action Mailer will
    #   ask the \Rails I18n class for a translated +:subject+ in the scope of
    #   <tt>[mailer_scope, action_name]</tt> or if this is missing, will translate the
    #   humanized version of the +action_name+
    # * +:to+ - Who the message is destined for, can be a string of addresses, or an array
    #   of addresses.
    # * +:from+ - Who the message is from
    # * +:cc+ - Who you would like to Carbon-Copy on this email, can be a string of addresses,
    #   or an array of addresses.
    # * +:bcc+ - Who you would like to Blind-Carbon-Copy on this email, can be a string of
    #   addresses, or an array of addresses.
    # * +:reply_to+ - Who to set the +Reply-To+ header of the email to.
    # * +:date+ - The date to say the email was sent on.
    #
    # You can set default values for any of the above headers (except +:date+)
    # by using the ::default class method:
    #
    #  class Notifier < ActionMailer::Base
    #    default from: 'no-reply@test.lindsaar.net',
    #            bcc: 'email_logger@test.lindsaar.net',
    #            reply_to: 'bounces@test.lindsaar.net'
    #  end
    #
    # If you need other headers not listed above, you can either pass them in
    # as part of the headers hash or use the <tt>headers['name'] = value</tt>
    # method.
    #
    # When a +:return_path+ is specified as header, that value will be used as
    # the 'envelope from' address for the Mail message. Setting this is useful
    # when you want delivery notifications sent to a different address than the
    # one in +:from+. Mail will actually use the +:return_path+ in preference
    # to the +:sender+ in preference to the +:from+ field for the 'envelope
    # from' value.
    #
    # If you do not pass a block to the +mail+ method, it will find all
    # templates in the view paths using by default the mailer name and the
    # method name that it is being called from, it will then create parts for
    # each of these templates intelligently, making educated guesses on correct
    # content type and sequence, and return a fully prepared +Mail::Message+
    # ready to call <tt>:deliver</tt> on to send.
    #
    # For example:
    #
    #   class Notifier < ActionMailer::Base
    #     default from: 'no-reply@test.lindsaar.net'
    #
    #     def welcome
    #       mail(to: 'mikel@test.lindsaar.net')
    #     end
    #   end
    #
    # Will look for all templates at "app/views/notifier" with name "welcome".
    # If no welcome template exists, it will raise an ActionView::MissingTemplate error.
    #
    # However, those can be customized:
    #
    #   mail(template_path: 'notifications', template_name: 'another')
    #
    # And now it will look for all templates at "app/views/notifications" with name "another".
    #
    # If you do pass a block, you can render specific templates of your choice:
    #
    #   mail(to: 'mikel@test.lindsaar.net') do |format|
    #     format.text
    #     format.html
    #   end
    #
    # You can even render plain text directly without using a template:
    #
    #   mail(to: 'mikel@test.lindsaar.net') do |format|
    #     format.text { render plain: "Hello Mikel!" }
    #     format.html { render html: "<h1>Hello Mikel!</h1>".html_safe }
    #   end
    #
    # Which will render a +multipart/alternative+ email with +text/plain+ and
    # +text/html+ parts.
    #
    # The block syntax also allows you to customize the part headers if desired:
    #
    #   mail(to: 'mikel@test.lindsaar.net') do |format|
    #     format.text(content_transfer_encoding: "base64")
    #     format.html
    #   end
    #
    def mail(headers = {}, &block)
      return message if @_mail_was_called && headers.blank? && !block

      # At the beginning, do not consider class default for content_type
      content_type = headers[:content_type]

      headers = apply_defaults(headers)

      # Apply charset at the beginning so all fields are properly quoted
      message.charset = charset = headers[:charset]

      # Set configure delivery behavior
      wrap_delivery_behavior!(headers[:delivery_method], headers[:delivery_method_options])

      assign_headers_to_message(message, headers)

      # Render the templates and blocks
      responses = collect_responses(headers, &block)
      @_mail_was_called = true

      create_parts_from_responses(message, responses)
      wrap_inline_attachments(message)

      # Set up content type, reapply charset and handle parts order
      message.content_type = set_content_type(message, content_type, headers[:content_type])
      message.charset      = charset

      if message.multipart?
        message.body.set_sort_order(headers[:parts_order])
        message.body.sort_parts!
      end

      message
    end

    private
      # Used by #mail to set the content type of the message.
      #
      # It will use the given +user_content_type+, or multipart if the mail
      # message has any attachments. If the attachments are inline, the content
      # type will be "multipart/related", otherwise "multipart/mixed".
      #
      # If there is no content type passed in via headers, and there are no
      # attachments, or the message is multipart, then the default content type is
      # used.
      def set_content_type(m, user_content_type, class_default) # :doc:
        params = m.content_type_parameters || {}
        case
        when user_content_type.present?
          user_content_type
        when m.has_attachments?
          if m.attachments.all?(&:inline?)
            ["multipart", "related", params]
          else
            ["multipart", "mixed", params]
          end
        when m.multipart?
          ["multipart", "alternative", params]
        else
          m.content_type || class_default
        end
      end

      # Translates the +subject+ using \Rails I18n class under <tt>[mailer_scope, action_name]</tt> scope.
      # If it does not find a translation for the +subject+ under the specified scope it will default to a
      # humanized version of the <tt>action_name</tt>.
      # If the subject has interpolations, you can pass them through the +interpolations+ parameter.
      def default_i18n_subject(interpolations = {}) # :doc:
        mailer_scope = self.class.mailer_name.tr("/", ".")
        I18n.t(:subject, **interpolations.merge(scope: [mailer_scope, action_name], default: action_name.humanize))
      end

      # Emails do not support relative path links.
      def self.supports_path? # :doc:
        false
      end

      def apply_defaults(headers)
        default_values = self.class.default.except(*headers.keys).transform_values do |value|
          compute_default(value)
        end

        headers_with_defaults = headers.reverse_merge(default_values)
        headers_with_defaults[:subject] ||= default_i18n_subject
        headers_with_defaults
      end

      def compute_default(value)
        return value unless value.is_a?(Proc)

        if value.arity == 1
          instance_exec(self, &value)
        else
          instance_exec(&value)
        end
      end

      def assign_headers_to_message(message, headers)
        assignable = headers.except(:parts_order, :content_type, :body, :template_name,
                                    :template_path, :delivery_method, :delivery_method_options)
        assignable.each { |k, v| message[k] = v }
      end

      def collect_responses(headers, &block)
        if block_given?
          collect_responses_from_block(headers, &block)
        elsif headers[:body]
          collect_responses_from_text(headers)
        else
          collect_responses_from_templates(headers)
        end
      end

      def collect_responses_from_block(headers)
        templates_name = headers[:template_name] || action_name
        collector = ActionMailer::Collector.new(lookup_context) { render(templates_name) }
        yield(collector)
        collector.responses
      end

      def collect_responses_from_text(headers)
        [{
          body: headers.delete(:body),
          content_type: headers[:content_type] || "text/plain"
        }]
      end

      def collect_responses_from_templates(headers)
        templates_path = headers[:template_path] || self.class.mailer_name
        templates_name = headers[:template_name] || action_name

        each_template(Array(templates_path), templates_name).map do |template|
          format = template.format || self.formats.first
          {
            body: render(template: template, formats: [format]),
            content_type: Mime[format].to_s
          }
        end
      end

      def each_template(paths, name, &block)
        templates = lookup_context.find_all(name, paths)
        if templates.empty?
          raise ActionView::MissingTemplate.new(paths, name, paths, false, "mailer")
        else
          templates.uniq(&:format).each(&block)
        end
      end

      def wrap_inline_attachments(message)
        # If we have both types of attachment, wrap all the inline attachments
        # in multipart/related, but not the actual attachments
        if message.attachments.detect(&:inline?) && message.attachments.detect { |a| !a.inline? }
          related = Mail::Part.new
          related.content_type = "multipart/related"
          mixed = [ related ]

          message.parts.each do |p|
            if p.attachment? && !p.inline?
              mixed << p
            else
              related.add_part(p)
            end
          end

          message.parts.clear
          mixed.each { |c| message.add_part(c) }
        end
      end

      def create_parts_from_responses(m, responses)
        if responses.size == 1 && !m.has_attachments?
          responses[0].each { |k, v| m[k] = v }
        elsif responses.size > 1 && m.has_attachments?
          container = Mail::Part.new
          container.content_type = "multipart/alternative"
          responses.each { |r| insert_part(container, r, m.charset) }
          m.add_part(container)
        else
          responses.each { |r| insert_part(m, r, m.charset) }
        end
      end

      def insert_part(container, response, charset)
        response[:charset] ||= charset
        part = Mail::Part.new(response)
        container.add_part(part)
      end

      # This and #instrument_name is for caching instrument
      def instrument_payload(key)
        {
          mailer: mailer_name,
          key: key
        }
      end

      def instrument_name
        "action_mailer"
      end

      def _protected_ivars
        PROTECTED_IVARS
      end

      ActiveSupport.run_load_hooks(:action_mailer, self)
  end
end

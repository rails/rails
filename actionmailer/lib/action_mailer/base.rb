module ActionMailer #:nodoc:
  # Usage:
  #
  #   class ApplicationMailer < ActionMailer::Base
  #     def post_notification(recipients, post)
  #       @recipients   = recipients
  #       @subject      = "[#{post.account.name} #{post.title}]"
  #       @body["post"] = post
  #       @from         = post.author.email_address_with_name
  #     end
  #     
  #     def comment_notification(recipient, comment)
  #       @recipients      = recipient.email_address_with_name
  #       @subject         = "[#{comment.post.project.client.firm.account.name}]" +
  #                          " Re: #{comment.post.title}"
  #       @body["comment"] = comment
  #       @from            = comment.author.email_address_with_name
  #       @sent_on         = comment.posted_on
  #     end
  #   end
  #
  #   # After this post_notification will look for "templates/application_mailer/post_notification.rhtml"
  #   ApplicationMailer.template_root = "templates"
  #  
  #   ApplicationMailer.create_comment_notification(david, hello_world)  # => a tmail object
  #   ApplicationMailer.deliver_comment_notification(david, hello_world) # sends the email
  class Base
    private_class_method :new

    # Template root determines the base from which template references will be made.
    cattr_accessor :template_root

    # The logger is used for generating information on the mailing run if available.
    # Can be set to nil for no logging. Compatible with both Ruby's own Logger and Log4r loggers.
    cattr_accessor :logger

    # Allows detailed configuration of the server:
    # * <tt>:address</tt> Allows you to use a remote mail server. Just change it away from it's default "localhost" setting.
    # * <tt>:port</tt> On the off change that your mail server doesn't run on port 25, you can change it.
    # * <tt>:domain</tt> If you need to specify a HELO domain, you can do it here.
    # * <tt>:user_name</tt> If your mail server requires authentication, set the username and password in these two settings.
    # * <tt>:password</tt> If your mail server requires authentication, set the username and password in these two settings.
    # * <tt>:authentication</tt> If your mail server requires authentication, you need to specify the authentication type here. 
    #   This is a symbol and one of :plain, :login, :cram_md5
    @@server_settings = { 
      :address        => "localhost", 
      :port           => 25, 
      :domain         => 'localhost.localdomain', 
      :user_name      => nil, 
      :password       => nil, 
      :authentication => nil
    }
    cattr_accessor :server_settings


    # Whether or not errors should be raised if the email fails to be delivered
    @@raise_delivery_errors = true
    cattr_accessor :raise_delivery_errors

    # Defines a delivery method. Possible values are :smtp (default), :sendmail, and :test.
    # Sendmail is assumed to be present at "/usr/sbin/sendmail".
    @@delivery_method = :smtp
    cattr_accessor :delivery_method
    
    # Determines whether deliver_* methods are actually carried out. By default they are,
    # but this can be turned off to help functional testing.
    @@perform_deliveries = true
    cattr_accessor :perform_deliveries
    
    # Keeps an array of all the emails sent out through the Action Mailer with delivery_method :test. Most useful
    # for unit and functional testing.
    @@deliveries = []
    cattr_accessor :deliveries

    attr_accessor :recipients, :subject, :body, :from, :sent_on, :bcc, :cc

    class << self
      def method_missing(method_symbol, *parameters)#:nodoc:
        case method_symbol.id2name
          when /^create_([_a-z]*)/
            create_from_action($1, *parameters)
          when /^deliver_([_a-z]*)/
            begin
              deliver(send("create_" + $1, *parameters))
            rescue Object => e
              raise e if raise_delivery_errors
            end
        end        
      end

      def mail(to, subject, body, from, timestamp = nil) #:nodoc:
        deliver(create(to, subject, body, from, timestamp))
      end

      def create(to, subject, body, from, timestamp = nil) #:nodoc:
        m = TMail::Mail.new
        m.to, m.subject, m.body, m.from = to, subject, body, from
        m.date = timestamp.respond_to?("to_time") ? timestamp.to_time : (timestamp || Time.now)    
        return m
      end

      def deliver(mail) #:nodoc:
        logger.info "Sent mail:\n #{mail.encoded}" unless logger.nil?
        send("perform_delivery_#{delivery_method}", mail) if perform_deliveries
      end

      private      
        def perform_delivery_smtp(mail)
          Net::SMTP.start(server_settings[:address], server_settings[:port], server_settings[:domain], 
              server_settings[:user_name], server_settings[:password], server_settings[:authentication]) do |smtp|
            smtp.sendmail(mail.encoded, mail.from_address, mail.destinations)
          end
        end

        def perform_delivery_sendmail(mail)
          IO.popen("/usr/sbin/sendmail -i -t","w+") do |sm|
            sm.print(mail.encoded)
            sm.flush
          end
        end

        def perform_delivery_test(mail)
          deliveries << mail
        end

        def create_from_action(method_name, *parameters)
          mailer = new
          mailer.body = {}
          mailer.send(method_name, *parameters)

          if String === mailer.body
            mail = create(mailer.recipients, mailer.subject, mailer.body, mailer.from, mailer.sent_on)
          else
            mail = create(mailer.recipients, mailer.subject, render_body(mailer, method_name), mailer.from, mailer.sent_on)
          end

          mail.bcc = @bcc if @bcc
          mail.cc  = @cc  if @cc
      
          return mail
        end
  
        def render_body(mailer, method_name)
          ActionView::Base.new(template_path, mailer.body).render_file(method_name)
        end
        
        def template_path
          template_root + "/" + Inflector.underscore(self.to_s)
        end
    end
  end
end

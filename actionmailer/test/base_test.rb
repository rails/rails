# encoding: utf-8
require 'abstract_unit'

class BaseTest < ActiveSupport::TestCase
  # TODO Add some tests for implicity layout render and url helpers
  # so we can get rid of old base tests altogether with old base.
  class BaseMailer < ActionMailer::Base
    self.mailer_name = "base_mailer"

    default :to => 'system@test.lindsaar.net',
            :from => 'jose@test.plataformatec.com',
            :reply_to => 'mikel@test.lindsaar.net'

    def welcome(hash = {})
      headers['X-SPAM'] = "Not SPAM"
      mail({:subject => "The first email on new API!"}.merge!(hash))
    end

    def welcome_with_headers(hash = {})
      headers hash
      mail
    end

    def welcome_from_another_path(path)
      mail(:template_name => "welcome", :template_path => path)
    end

    def html_only(hash = {})
      mail(hash)
    end

    def plain_text_only(hash = {})
      mail(hash)
    end

    def attachment_with_content(hash = {})
      attachments['invoice.pdf'] = 'This is test File content'
      mail(hash)
    end

    def attachment_with_hash
      attachments['invoice.jpg'] = { :data => "you smiling", :mime_type => "image/x-jpg",
        :transfer_encoding => "base64" }
      mail
    end

    def implicit_multipart(hash = {})
      attachments['invoice.pdf'] = 'This is test File content' if hash.delete(:attachments)
      mail(hash)
    end

    def implicit_with_locale(hash = {})
      mail(hash)
    end

    def explicit_multipart(hash = {})
      attachments['invoice.pdf'] = 'This is test File content' if hash.delete(:attachments)
      mail(hash) do |format|
        format.text { render :text => "TEXT Explicit Multipart" }
        format.html { render :text => "HTML Explicit Multipart" }
      end
    end

    def explicit_multipart_templates(hash = {})
      mail(hash) do |format|
        format.html
        format.text
      end
    end

    def explicit_multipart_with_any(hash = {})
      mail(hash) do |format|
        format.any(:text, :html){ render :text => "Format with any!" }
      end
    end

    def custom_block(include_html=false)
      mail do |format|
        format.text(:content_transfer_encoding => "base64"){ render "welcome" }
        format.html{ render "welcome" } if include_html
      end
    end

    def implicit_different_template(template_name='')
      mail(:template_name => template_name)
    end

    def explicit_different_template(template_name='')
      mail do |format|
        format.text { render :template => "#{mailer_name}/#{template_name}" }
        format.html { render :template => "#{mailer_name}/#{template_name}" }
      end
    end

    def different_layout(layout_name='')
      mail do |format|
        format.text { render :layout => layout_name }
        format.html { render :layout => layout_name }
      end
    end
  end

  test "method call to mail does not raise error" do
    assert_nothing_raised { BaseMailer.welcome }
  end

  # Basic mail usage without block
  test "mail() should set the headers of the mail message" do
    email = BaseMailer.welcome
    assert_equal(['system@test.lindsaar.net'],    email.to)
    assert_equal(['jose@test.plataformatec.com'], email.from)
    assert_equal('The first email on new API!',   email.subject)
  end

  test "mail() with from overwrites the class level default" do
    email = BaseMailer.welcome(:from => 'someone@example.com',
                               :to   => 'another@example.org')
    assert_equal(['someone@example.com'], email.from)
    assert_equal(['another@example.org'], email.to)
  end

  test "mail() with bcc, cc, content_type, charset, mime_version, reply_to and date" do
    @time = Time.now.beginning_of_day.to_datetime
    email = BaseMailer.welcome(:bcc => 'bcc@test.lindsaar.net',
                               :cc  => 'cc@test.lindsaar.net',
                               :content_type => 'multipart/mixed',
                               :charset => 'iso-8559-1',
                               :mime_version => '2.0',
                               :reply_to => 'reply-to@test.lindsaar.net',
                               :date => @time)
    assert_equal(['bcc@test.lindsaar.net'],      email.bcc)
    assert_equal(['cc@test.lindsaar.net'],       email.cc)
    assert_equal('multipart/mixed',              email.content_type)
    assert_equal('iso-8559-1',                   email.charset)
    assert_equal('2.0',                          email.mime_version)
    assert_equal(['reply-to@test.lindsaar.net'], email.reply_to)
    assert_equal(@time,                          email.date)
  end

  test "mail() renders the template using the method being processed" do
    email = BaseMailer.welcome
    assert_equal("Welcome", email.body.encoded)
  end

  test "can pass in :body to the mail method hash" do
    email = BaseMailer.welcome(:body => "Hello there")
    assert_equal("text/plain", email.mime_type)
    assert_equal("Hello there", email.body.encoded)
  end

  # Custom headers
  test "custom headers" do
    email = BaseMailer.welcome
    assert_equal("Not SPAM", email['X-SPAM'].decoded)
  end

  test "can pass random headers in as a hash to mail" do
    hash = {'X-Special-Domain-Specific-Header' => "SecretValue",
            'In-Reply-To' => '1234@mikel.me.com' }
    mail = BaseMailer.welcome(hash)
    assert_equal('SecretValue', mail['X-Special-Domain-Specific-Header'].decoded)
    assert_equal('1234@mikel.me.com', mail['In-Reply-To'].decoded)
  end

  test "can pass random headers in as a hash" do
    hash = {'X-Special-Domain-Specific-Header' => "SecretValue",
            'In-Reply-To' => '1234@mikel.me.com' }
    mail = BaseMailer.welcome_with_headers(hash)
    assert_equal('SecretValue', mail['X-Special-Domain-Specific-Header'].decoded)
    assert_equal('1234@mikel.me.com', mail['In-Reply-To'].decoded)
  end

  # Attachments
  test "attachment with content" do
    email = BaseMailer.attachment_with_content
    assert_equal(1, email.attachments.length)
    assert_equal('invoice.pdf', email.attachments[0].filename)
    assert_equal('This is test File content', email.attachments['invoice.pdf'].decoded)
  end

  test "attachment gets content type from filename" do
    email = BaseMailer.attachment_with_content
    assert_equal('invoice.pdf', email.attachments[0].filename)
  end

  test "attachment with hash" do
    email = BaseMailer.attachment_with_hash
    assert_equal(1, email.attachments.length)
    assert_equal('invoice.jpg', email.attachments[0].filename)
    expected = "\312\213\254\232)b"
    expected.force_encoding(Encoding::BINARY) if '1.9'.respond_to?(:force_encoding)
    assert_equal expected, email.attachments['invoice.jpg'].decoded
  end

  test "sets mime type to multipart/mixed when attachment is included" do
    email = BaseMailer.attachment_with_content
    assert_equal(1, email.attachments.length)
    assert_equal("multipart/mixed", email.mime_type)
  end

  test "adds the rendered template as part" do
    email = BaseMailer.attachment_with_content
    assert_equal(2, email.parts.length)
    assert_equal("multipart/mixed", email.mime_type)
    assert_equal("text/html", email.parts[0].mime_type)
    assert_equal("Attachment with content", email.parts[0].body.encoded)
    assert_equal("application/pdf", email.parts[1].mime_type)
    assert_equal("VGhpcyBpcyB0ZXN0IEZpbGUgY29udGVudA==\r\n", email.parts[1].body.encoded)
  end

  test "adds the given :body as part" do
    email = BaseMailer.attachment_with_content(:body => "I'm the eggman")
    assert_equal(2, email.parts.length)
    assert_equal("multipart/mixed", email.mime_type)
    assert_equal("text/plain", email.parts[0].mime_type)
    assert_equal("I'm the eggman", email.parts[0].body.encoded)
    assert_equal("application/pdf", email.parts[1].mime_type)
    assert_equal("VGhpcyBpcyB0ZXN0IEZpbGUgY29udGVudA==\r\n", email.parts[1].body.encoded)
  end

  # Defaults values
  test "uses default charset from class" do
    with_default BaseMailer, :charset => "US-ASCII" do
      email = BaseMailer.welcome
      assert_equal("US-ASCII", email.charset)

      email = BaseMailer.welcome(:charset => "iso-8559-1")
      assert_equal("iso-8559-1", email.charset)
    end
  end

  test "uses default content type from class" do
    with_default BaseMailer, :content_type => "text/html" do
      email = BaseMailer.welcome
      assert_equal("text/html", email.mime_type)

      email = BaseMailer.welcome(:content_type => "text/plain")
      assert_equal("text/plain", email.mime_type)
    end
  end

  test "uses default mime version from class" do
    with_default BaseMailer, :mime_version => "2.0" do
      email = BaseMailer.welcome
      assert_equal("2.0", email.mime_version)

      email = BaseMailer.welcome(:mime_version => "1.0")
      assert_equal("1.0", email.mime_version)
    end
  end

  test "uses random default headers from class" do
    with_default BaseMailer, "X-Custom" => "Custom" do
      email = BaseMailer.welcome
      assert_equal("Custom", email["X-Custom"].decoded)
    end
  end

  test "subject gets default from I18n" do
    BaseMailer.default :subject => nil
    email = BaseMailer.welcome(:subject => nil)
    assert_equal "Welcome", email.subject

    I18n.backend.store_translations('en', :actionmailer => {:base_mailer => {:welcome => {:subject => "New Subject!"}}})
    email = BaseMailer.welcome(:subject => nil)
    assert_equal "New Subject!", email.subject
  end

  # Implicit multipart
  test "implicit multipart" do
    email = BaseMailer.implicit_multipart
    assert_equal(2, email.parts.size)
    assert_equal("multipart/alternative", email.mime_type)
    assert_equal("text/plain", email.parts[0].mime_type)
    assert_equal("TEXT Implicit Multipart", email.parts[0].body.encoded)
    assert_equal("text/html", email.parts[1].mime_type)
    assert_equal("HTML Implicit Multipart", email.parts[1].body.encoded)
  end

  test "implicit multipart with sort order" do
    order = ["text/html", "text/plain"]
    with_default BaseMailer, :parts_order => order do
      email = BaseMailer.implicit_multipart
      assert_equal("text/html",  email.parts[0].mime_type)
      assert_equal("text/plain", email.parts[1].mime_type)

      email = BaseMailer.implicit_multipart(:parts_order => order.reverse)
      assert_equal("text/plain", email.parts[0].mime_type)
      assert_equal("text/html",  email.parts[1].mime_type)
    end
  end

  test "implicit multipart with attachments creates nested parts" do
    email = BaseMailer.implicit_multipart(:attachments => true)
    assert_equal("application/pdf", email.parts[0].mime_type)
    assert_equal("multipart/alternative", email.parts[1].mime_type)
    assert_equal("text/plain", email.parts[1].parts[0].mime_type)
    assert_equal("TEXT Implicit Multipart", email.parts[1].parts[0].body.encoded)
    assert_equal("text/html", email.parts[1].parts[1].mime_type)
    assert_equal("HTML Implicit Multipart", email.parts[1].parts[1].body.encoded)
  end

  test "implicit multipart with attachments and sort order" do
    order = ["text/html", "text/plain"]
    with_default BaseMailer, :parts_order => order do
      email = BaseMailer.implicit_multipart(:attachments => true)
      assert_equal("application/pdf", email.parts[0].mime_type)
      assert_equal("multipart/alternative", email.parts[1].mime_type)
      assert_equal("text/plain", email.parts[1].parts[1].mime_type)
      assert_equal("text/html", email.parts[1].parts[0].mime_type)
    end
  end

  test "implicit multipart with default locale" do
    email = BaseMailer.implicit_with_locale
    assert_equal(2, email.parts.size)
    assert_equal("multipart/alternative", email.mime_type)
    assert_equal("text/plain", email.parts[0].mime_type)
    assert_equal("Implicit with locale TEXT", email.parts[0].body.encoded)
    assert_equal("text/html", email.parts[1].mime_type)
    assert_equal("Implicit with locale EN HTML", email.parts[1].body.encoded)
  end

  test "implicit multipart with other locale" do
    swap I18n, :locale => :pl do
      email = BaseMailer.implicit_with_locale
      assert_equal(2, email.parts.size)
      assert_equal("multipart/alternative", email.mime_type)
      assert_equal("text/plain", email.parts[0].mime_type)
      assert_equal("Implicit with locale PL TEXT", email.parts[0].body.encoded)
      assert_equal("text/html", email.parts[1].mime_type)
      assert_equal("Implicit with locale HTML", email.parts[1].body.encoded)
    end
  end

  test "implicit multipart with several view paths uses the first one with template" do
    old = BaseMailer.view_paths
    begin
      BaseMailer.view_paths = [File.join(FIXTURE_LOAD_PATH, "another.path")] + old.dup
      email = BaseMailer.welcome
      assert_equal("Welcome from another path", email.body.encoded)
    ensure
      BaseMailer.view_paths = old
    end
  end

  test "implicit multipart with inexistent templates uses the next view path" do
    old = BaseMailer.view_paths
    begin
      BaseMailer.view_paths = [File.join(FIXTURE_LOAD_PATH, "unknown")] + old.dup
      email = BaseMailer.welcome
      assert_equal("Welcome", email.body.encoded)
    ensure
      BaseMailer.view_paths = old
    end
  end

  # Explicit multipart
  test "explicit multipart" do
    email = BaseMailer.explicit_multipart
    assert_equal(2, email.parts.size)
    assert_equal("multipart/alternative", email.mime_type)
    assert_equal("text/plain", email.parts[0].mime_type)
    assert_equal("TEXT Explicit Multipart", email.parts[0].body.encoded)
    assert_equal("text/html", email.parts[1].mime_type)
    assert_equal("HTML Explicit Multipart", email.parts[1].body.encoded)
  end

  test "explicit multipart does not sort order" do
    order = ["text/html", "text/plain"]
    with_default BaseMailer, :parts_order => order do
      email = BaseMailer.explicit_multipart
      assert_equal("text/plain", email.parts[0].mime_type)
      assert_equal("text/html",  email.parts[1].mime_type)

      email = BaseMailer.explicit_multipart(:parts_order => order.reverse)
      assert_equal("text/plain", email.parts[0].mime_type)
      assert_equal("text/html",  email.parts[1].mime_type)
    end
  end

  test "explicit multipart with attachments creates nested parts" do
    email = BaseMailer.explicit_multipart(:attachments => true)
    assert_equal("application/pdf", email.parts[0].mime_type)
    assert_equal("multipart/alternative", email.parts[1].mime_type)
    assert_equal("text/plain", email.parts[1].parts[0].mime_type)
    assert_equal("TEXT Explicit Multipart", email.parts[1].parts[0].body.encoded)
    assert_equal("text/html", email.parts[1].parts[1].mime_type)
    assert_equal("HTML Explicit Multipart", email.parts[1].parts[1].body.encoded)
  end

  test "explicit multipart with templates" do
    email = BaseMailer.explicit_multipart_templates
    assert_equal(2, email.parts.size)
    assert_equal("multipart/alternative", email.mime_type)
    assert_equal("text/html", email.parts[0].mime_type)
    assert_equal("HTML Explicit Multipart Templates", email.parts[0].body.encoded)
    assert_equal("text/plain", email.parts[1].mime_type)
    assert_equal("TEXT Explicit Multipart Templates", email.parts[1].body.encoded)
  end

  test "explicit multipart with any" do
    email = BaseMailer.explicit_multipart_with_any
    assert_equal(2, email.parts.size)
    assert_equal("multipart/alternative", email.mime_type)
    assert_equal("text/plain", email.parts[0].mime_type)
    assert_equal("Format with any!", email.parts[0].body.encoded)
    assert_equal("text/html", email.parts[1].mime_type)
    assert_equal("Format with any!", email.parts[1].body.encoded)
  end

  test "explicit multipart with options" do
    email = BaseMailer.custom_block(true)
    email.ready_to_send!
    assert_equal(2, email.parts.size)
    assert_equal("multipart/alternative", email.mime_type)
    assert_equal("text/plain", email.parts[0].mime_type)
    assert_equal("base64", email.parts[0].content_transfer_encoding)
    assert_equal("text/html", email.parts[1].mime_type)
    assert_equal("7bit", email.parts[1].content_transfer_encoding)
  end

  test "explicit multipart should be multipart" do
    mail = BaseMailer.explicit_multipart
    assert_not_nil(mail.content_type_parameters[:boundary])
  end

  test "should set a content type if only has an html part" do
    mail = BaseMailer.html_only
    assert_equal('text/html', mail.mime_type)
  end
  
  test "should set a content type if only has an plain text part" do
    mail = BaseMailer.plain_text_only
    assert_equal('text/plain', mail.mime_type)
  end

  test "explicit multipart with one part is rendered as body" do
    email = BaseMailer.custom_block
    assert_equal(0, email.parts.size)
    assert_equal("text/plain", email.mime_type)
    assert_equal("base64", email.content_transfer_encoding)
  end

  # Class level API with method missing
  test "should respond to action methods" do
    assert BaseMailer.respond_to?(:welcome)
    assert BaseMailer.respond_to?(:implicit_multipart)
    assert !BaseMailer.respond_to?(:mail)
    assert !BaseMailer.respond_to?(:headers)
  end

  test "calling just the action should return the generated mail object" do
    BaseMailer.deliveries.clear
    email = BaseMailer.welcome
    assert_equal(0, BaseMailer.deliveries.length)
    assert_equal('The first email on new API!', email.subject)
  end

  test "calling deliver on the action should deliver the mail object" do
    BaseMailer.deliveries.clear
    BaseMailer.expects(:deliver_mail).once
    mail = BaseMailer.welcome.deliver
    assert_instance_of Mail::Message, mail
  end

  test "calling deliver on the action should increment the deliveries collection if using the test mailer" do
    BaseMailer.delivery_method = :test
    BaseMailer.deliveries.clear
    BaseMailer.welcome.deliver
    assert_equal(1, BaseMailer.deliveries.length)
  end
  
  test "calling deliver, ActionMailer should yield back to mail to let it call :do_delivery on itself" do
    mail = Mail::Message.new
    mail.expects(:do_delivery).once
    BaseMailer.expects(:welcome).returns(mail)
    BaseMailer.welcome.deliver
  end

  # Rendering
  test "you can specify a different template for implicit render" do
    mail = BaseMailer.implicit_different_template('implicit_multipart')
    assert_equal("HTML Implicit Multipart", mail.html_part.body.decoded)
    assert_equal("TEXT Implicit Multipart", mail.text_part.body.decoded)
  end

  test "you can specify a different template for explicit render" do
    mail = BaseMailer.explicit_different_template('explicit_multipart_templates')
    assert_equal("HTML Explicit Multipart Templates", mail.html_part.body.decoded)
    assert_equal("TEXT Explicit Multipart Templates", mail.text_part.body.decoded)
  end

  test "you can specify a different layout" do
    mail = BaseMailer.different_layout('different_layout')
    assert_equal("HTML -- HTML", mail.html_part.body.decoded)
    assert_equal("PLAIN -- PLAIN", mail.text_part.body.decoded)
  end

  test "you can specify the template path for implicit lookup" do
    mail = BaseMailer.welcome_from_another_path('another.path/base_mailer')
    assert_equal("Welcome from another path", mail.body.encoded)

    mail = BaseMailer.welcome_from_another_path(['unknown/invalid', 'another.path/base_mailer'])
    assert_equal("Welcome from another path", mail.body.encoded)
  end
  
  # Before and After hooks
  
  class MyObserver
    def self.delivered_email(mail)
    end
  end
  
  test "you can register an observer to the mail object that gets informed on email delivery" do
    ActionMailer::Base.register_observer(MyObserver)
    mail = BaseMailer.welcome
    MyObserver.expects(:delivered_email).with(mail)
    mail.deliver
  end

  class MyInterceptor
    def self.delivering_email(mail)
    end
  end

  test "you can register an interceptor to the mail object that gets passed the mail object before delivery" do
    ActionMailer::Base.register_interceptor(MyInterceptor)
    mail = BaseMailer.welcome
    MyInterceptor.expects(:delivering_email).with(mail)
    mail.deliver
  end

  protected

    # Execute the block setting the given values and restoring old values after
    # the block is executed.
    def swap(klass, new_values)
      old_values = {}
      new_values.each do |key, value|
        old_values[key] = klass.send key
        klass.send :"#{key}=", value
      end
      yield
    ensure
      old_values.each do |key, value|
        klass.send :"#{key}=", value
      end
    end

    def with_default(klass, new_values)
      old = klass.default_params
      klass.default(new_values)
      yield
    ensure
      klass.default_params = old
    end
end

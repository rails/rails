# encoding: utf-8
require 'abstract_unit'

#  class Notifier < ActionMailer::Base
#    delivers_from 'notifications@example.com'
#
#    def welcome(user)
#      @user = user # available to the view
#      mail(:subject => 'Welcome!', :to => user.email_address)
#      # auto renders both welcome.text.erb and welcome.html.erb
#    end
#
#    def goodbye(user)
#      headers["X-SPAM"] = 'Not-SPAM'
#      mail(:subject => 'Goodbye', :to => user.email_address) do |format|
#        format.html { render "shared_template "}
#        format.text # goodbye.text.erb
#      end
#    end
#
#    def surprise(user, gift)
#      attachments[gift.name] = File.read(gift.path)
#      mail(:subject => 'Surprise!', :to => user.email_address) do |format|
#        format.html(:charset => "ascii")            # surprise.html.erb
#        format.text(:transfer_encoding => "base64") # surprise.text.erb
#      end
#    end
#
#    def special_surprise(user, gift)
#      attachments[gift.name] = { :content_type => "application/x-gzip", :content => File.read(gift.path) }
#      mail(:to => 'special@example.com') # subject not required
#      # auto renders both special_surprise.text.erb and special_surprise.html.erb
#    end
#  end
#
#  mail = Notifier.welcome(user)         # => returns a Mail object
#  mail.deliver
#
#  Notifier.welcome(user).deliver # => creates and sends the Mail in one step
class BaseTest < ActiveSupport::TestCase
  DEFAULT_HEADERS = {
    :to => 'mikel@test.lindsaar.net',
    :from => 'jose@test.plataformatec.com',
    :subject => 'The first email on new API!'
  }

  # TODO Think on the simple case where I want to send an e-mail
  # with attachment and small text (without need to add a template).
  class BaseMailer < ActionMailer::Base
    self.mailer_name = "base_mailer"

    def welcome(hash = {})
      headers['X-SPAM'] = "Not SPAM"
      mail(DEFAULT_HEADERS.merge(hash))
    end

    def attachment_with_content(hash = {})
      attachments['invoice.pdf'] = 'This is test File content'
      mail(DEFAULT_HEADERS.merge(hash))
    end

    def attachment_with_hash
      attachments['invoice.jpg'] = { :content => "you smiling", :mime_type => "image/x-jpg",
        :transfer_encoding => "base64" }
      mail(DEFAULT_HEADERS)
    end

    def implicit_multipart(hash = {})
      attachments['invoice.pdf'] = 'This is test File content' if hash.delete(:attachments)
      mail(DEFAULT_HEADERS.merge(hash))
    end

    def explicit_multipart(hash = {})
      attachments['invoice.pdf'] = 'This is test File content' if hash.delete(:attachments)
      mail(DEFAULT_HEADERS.merge(hash)) do |format|
        format.text { render :text => "TEXT Explicit Multipart" }
        format.html { render :text => "HTML Explicit Multipart" }
      end
    end

    def explicit_multipart_templates(hash = {})
      mail(DEFAULT_HEADERS.merge(hash)) do |format|
        format.html
        format.text
      end
    end

    def explicit_multipart_with_any(hash = {})
      mail(DEFAULT_HEADERS.merge(hash)) do |format|
        format.any(:text, :html){ render :text => "Format with any!" }
      end
    end
  end

  test "method call to mail does not raise error" do
    assert_nothing_raised { BaseMailer.deliver_welcome }
  end

  # Basic mail usage without block
  test "mail() should set the headers of the mail message" do
    email = BaseMailer.deliver_welcome
    assert_equal(email.to,      ['mikel@test.lindsaar.net'])
    assert_equal(email.from,    ['jose@test.plataformatec.com'])
    assert_equal(email.subject, 'The first email on new API!')
  end

  test "mail() with bcc, cc, content_type, charset, mime_version, reply_to and date" do
    @time = Time.now
    email = BaseMailer.deliver_welcome(:bcc => 'bcc@test.lindsaar.net',
                                       :cc  => 'cc@test.lindsaar.net',
                                       :content_type => 'multipart/mixed',
                                       :charset => 'iso-8559-1',
                                       :mime_version => '2.0',
                                       :reply_to => 'reply-to@test.lindsaar.net',
                                       :date => @time)
    assert_equal(email.bcc,           ['bcc@test.lindsaar.net'])
    assert_equal(email.cc,            ['cc@test.lindsaar.net'])
    assert_equal(email.content_type,  'multipart/mixed')
    assert_equal(email.charset,       'iso-8559-1')
    assert_equal(email.mime_version,  '2.0')
    assert_equal(email.reply_to,      ['reply-to@test.lindsaar.net'])
    assert_equal(email.date,          @time)
  end

  test "mail() renders the template using the method being processed" do
    email = BaseMailer.deliver_welcome
    assert_equal("Welcome", email.body.encoded)
  end

  test "can pass in :body to the mail method hash" do
    email = BaseMailer.deliver_welcome(:body => "Hello there")
    assert_equal("text/plain", email.mime_type)
    assert_equal("Hello there", email.body.encoded)
  end

  # Custom headers
  test "custom headers" do
    email = BaseMailer.deliver_welcome
    assert_equal("Not SPAM", email['X-SPAM'].decoded)
  end

  # Attachments
  test "attachment with content" do
    email = BaseMailer.deliver_attachment_with_content
    assert_equal(1, email.attachments.length)
    assert_equal('invoice.pdf', email.attachments[0].filename)
    assert_equal('This is test File content', email.attachments['invoice.pdf'].decoded)
  end

  test "attachment gets content type from filename" do
    email = BaseMailer.deliver_attachment_with_content
    assert_equal('invoice.pdf', email.attachments[0].filename)
  end

  test "attachment with hash" do
    email = BaseMailer.deliver_attachment_with_hash
    assert_equal(1, email.attachments.length)
    assert_equal('invoice.jpg', email.attachments[0].filename)
    assert_equal("\312\213\254\232)b", email.attachments['invoice.jpg'].decoded)
  end

  test "sets mime type to multipart/mixed when attachment is included" do
    email = BaseMailer.deliver_attachment_with_content
    assert_equal(1, email.attachments.length)
    assert_equal("multipart/mixed", email.mime_type)
  end

  test "adds the rendered template as part" do
    email = BaseMailer.deliver_attachment_with_content
    assert_equal(2, email.parts.length)
    assert_equal("multipart/mixed", email.mime_type)
    assert_equal("text/html", email.parts[0].mime_type)
    assert_equal("Attachment with content", email.parts[0].body.encoded)
    assert_equal("application/pdf", email.parts[1].mime_type)
    assert_equal("VGhpcyBpcyB0ZXN0IEZpbGUgY29udGVudA==\r\n", email.parts[1].body.encoded)
  end

  test "adds the given :body as part" do
    email = BaseMailer.deliver_attachment_with_content(:body => "I'm the eggman")
    assert_equal(2, email.parts.length)
    assert_equal("multipart/mixed", email.mime_type)
    assert_equal("text/plain", email.parts[0].mime_type)
    assert_equal("I'm the eggman", email.parts[0].body.encoded)
    assert_equal("application/pdf", email.parts[1].mime_type)
    assert_equal("VGhpcyBpcyB0ZXN0IEZpbGUgY29udGVudA==\r\n", email.parts[1].body.encoded)
  end

  # Defaults values
  test "uses default charset from class" do
    swap BaseMailer, :default_charset => "US-ASCII" do
      email = BaseMailer.deliver_welcome
      assert_equal("US-ASCII", email.charset)

      email = BaseMailer.deliver_welcome(:charset => "iso-8559-1")
      assert_equal("iso-8559-1", email.charset)
    end
  end

  test "uses default content type from class" do
    swap BaseMailer, :default_content_type => "text/html" do
      email = BaseMailer.deliver_welcome
      assert_equal("text/html", email.mime_type)

      email = BaseMailer.deliver_welcome(:content_type => "text/plain")
      assert_equal("text/plain", email.mime_type)
    end
  end

  test "uses default mime version from class" do
    swap BaseMailer, :default_mime_version => "2.0" do
      email = BaseMailer.deliver_welcome
      assert_equal("2.0", email.mime_version)

      email = BaseMailer.deliver_welcome(:mime_version => "1.0")
      assert_equal("1.0", email.mime_version)
    end
  end

  test "subject gets default from I18n" do
    email = BaseMailer.deliver_welcome(:subject => nil)
    assert_equal "Welcome", email.subject

    I18n.backend.store_translations('en', :actionmailer => {:base_mailer => {:welcome => {:subject => "New Subject!"}}})
    email = BaseMailer.deliver_welcome(:subject => nil)
    assert_equal "New Subject!", email.subject
  end

  # Implicit multipart
  test "implicit multipart" do
    email = BaseMailer.deliver_implicit_multipart
    assert_equal(2, email.parts.size)
    assert_equal("multipart/alternate", email.mime_type)
    assert_equal("text/plain", email.parts[0].mime_type)
    assert_equal("TEXT Implicit Multipart", email.parts[0].body.encoded)
    assert_equal("text/html", email.parts[1].mime_type)
    assert_equal("HTML Implicit Multipart", email.parts[1].body.encoded)
  end

  test "implicit multipart with sort order" do
    order = ["text/html", "text/plain"]
    swap BaseMailer, :default_implicit_parts_order => order do
      email = BaseMailer.deliver_implicit_multipart
      assert_equal("text/html",  email.parts[0].mime_type)
      assert_equal("text/plain", email.parts[1].mime_type)

      email = BaseMailer.deliver_implicit_multipart(:parts_order => order.reverse)
      assert_equal("text/plain", email.parts[0].mime_type)
      assert_equal("text/html",  email.parts[1].mime_type)
    end
  end

  test "implicit multipart with attachments creates nested parts" do
    email = BaseMailer.deliver_implicit_multipart(:attachments => true)
    assert_equal("application/pdf", email.parts[0].mime_type)
    assert_equal("multipart/alternate", email.parts[1].mime_type)
    assert_equal("text/plain", email.parts[1].parts[0].mime_type)
    assert_equal("TEXT Implicit Multipart", email.parts[1].parts[0].body.encoded)
    assert_equal("text/html", email.parts[1].parts[1].mime_type)
    assert_equal("HTML Implicit Multipart", email.parts[1].parts[1].body.encoded)
  end

  test "implicit multipart with attachments and sort order" do
    order = ["text/html", "text/plain"]
    swap BaseMailer, :default_implicit_parts_order => order do
      email = BaseMailer.deliver_implicit_multipart(:attachments => true)
      assert_equal("application/pdf", email.parts[0].mime_type)
      assert_equal("multipart/alternate", email.parts[1].mime_type)
      assert_equal("text/plain", email.parts[1].parts[1].mime_type)
      assert_equal("text/html", email.parts[1].parts[0].mime_type)
    end
  end

  # Explicit multipart
  test "explicit multipart" do
    email = BaseMailer.deliver_explicit_multipart
    assert_equal(2, email.parts.size)
    assert_equal("multipart/alternate", email.mime_type)
    assert_equal("text/plain", email.parts[0].mime_type)
    assert_equal("TEXT Explicit Multipart", email.parts[0].body.encoded)
    assert_equal("text/html", email.parts[1].mime_type)
    assert_equal("HTML Explicit Multipart", email.parts[1].body.encoded)
  end

  test "explicit multipart does not sort order" do
    order = ["text/html", "text/plain"]
    swap BaseMailer, :default_implicit_parts_order => order do
      email = BaseMailer.deliver_explicit_multipart
      assert_equal("text/plain", email.parts[0].mime_type)
      assert_equal("text/html",  email.parts[1].mime_type)

      email = BaseMailer.deliver_explicit_multipart(:parts_order => order.reverse)
      assert_equal("text/plain", email.parts[0].mime_type)
      assert_equal("text/html",  email.parts[1].mime_type)
    end
  end

  test "explicit multipart with attachments creates nested parts" do
    email = BaseMailer.deliver_explicit_multipart(:attachments => true)
    assert_equal("application/pdf", email.parts[0].mime_type)
    assert_equal("multipart/alternate", email.parts[1].mime_type)
    assert_equal("text/plain", email.parts[1].parts[0].mime_type)
    assert_equal("TEXT Explicit Multipart", email.parts[1].parts[0].body.encoded)
    assert_equal("text/html", email.parts[1].parts[1].mime_type)
    assert_equal("HTML Explicit Multipart", email.parts[1].parts[1].body.encoded)
  end

  test "explicit multipart with templates" do
    email = BaseMailer.deliver_explicit_multipart_templates
    assert_equal(2, email.parts.size)
    assert_equal("multipart/alternate", email.mime_type)
    assert_equal("text/html", email.parts[0].mime_type)
    assert_equal("HTML Explicit Multipart Templates", email.parts[0].body.encoded)
    assert_equal("text/plain", email.parts[1].mime_type)
    assert_equal("TEXT Explicit Multipart Templates", email.parts[1].body.encoded)
  end

  test "explicit multipart with any" do
    email = BaseMailer.deliver_explicit_multipart_with_any
    assert_equal(2, email.parts.size)
    assert_equal("multipart/alternate", email.mime_type)
    assert_equal("text/plain", email.parts[0].mime_type)
    assert_equal("Format with any!", email.parts[0].body.encoded)
    assert_equal("text/html", email.parts[1].mime_type)
    assert_equal("Format with any!", email.parts[1].body.encoded)
  end


  protected

    # Execute the block setting the given values and restoring old values after
    # the block is executed.
    def swap(object, new_values)
      old_values = {}
      new_values.each do |key, value|
        old_values[key] = object.send key
        object.send :"#{key}=", value
      end
      yield
    ensure
      old_values.each do |key, value|
        object.send :"#{key}=", value
      end
    end

end
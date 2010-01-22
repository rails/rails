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

  class TestMailer < ActionMailer::Base
    def welcome(hash = {})
      headers['X-SPAM'] = "Not SPAM"
      mail(DEFAULT_HEADERS.merge(hash))
    end

    def attachment_with_content
      attachments['invoice.pdf'] = 'This is test File content'
      mail(DEFAULT_HEADERS)
    end

    def attachment_with_hash
      attachments['invoice.jpg'] = { :content => "you smiling", :mime_type => "image/x-jpg",
        :transfer_encoding => "base64" }
      mail(DEFAULT_HEADERS)
    end
  end

  test "method call to mail does not raise error" do
    assert_nothing_raised { TestMailer.deliver_welcome }
  end

  test "mail() should set the headers of the mail message" do
    email = TestMailer.deliver_welcome
    assert_equal(email.to,      ['mikel@test.lindsaar.net'])
    assert_equal(email.from,    ['jose@test.plataformatec.com'])
    assert_equal(email.subject, 'The first email on new API!')
  end

  test "mail() with bcc, cc, content_type, charset, mime_version, reply_to and date" do
    @time = Time.now
    email = TestMailer.deliver_welcome(:bcc => 'bcc@test.lindsaar.net',
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

  test "custom headers" do
    email = TestMailer.deliver_welcome
    assert_equal("Not SPAM", email['X-SPAM'].decoded)
  end

  test "attachment with content" do
    email = TestMailer.deliver_attachment_with_content
    assert_equal(1, email.attachments.length)
    assert_equal('invoice.pdf', email.attachments[0].filename)
    assert_equal('This is test File content', email.attachments['invoice.pdf'].decoded)
  end

  test "attachment gets content type from filename" do
    email = TestMailer.deliver_attachment_with_content
    assert_equal('invoice.pdf', email.attachments[0].filename)
  end

  test "attachment with hash" do
    email = TestMailer.deliver_attachment_with_hash
    assert_equal(1, email.attachments.length)
    assert_equal('invoice.jpg', email.attachments[0].filename)
    assert_equal("\312\213\254\232)b", email.attachments['invoice.jpg'].decoded)
  end

  test "uses default charset from class" do
    swap TestMailer, :default_charset => "US-ASCII" do
      email = TestMailer.deliver_welcome
      assert_equal("US-ASCII", email.charset)

      email = TestMailer.deliver_welcome(:charset => "iso-8559-1")
      assert_equal("iso-8559-1", email.charset)
    end
  end

  test "uses default content type from class" do
    swap TestMailer, :default_content_type => "text/html" do
      email = TestMailer.deliver_welcome
      assert_equal("text/html", email.mime_type)

      email = TestMailer.deliver_welcome(:content_type => "application/xml")
      assert_equal("application/xml", email.mime_type)
    end
  end

  test "uses default mime version from class" do
    swap TestMailer, :default_mime_version => "2.0" do
      email = TestMailer.deliver_welcome
      assert_equal("2.0", email.mime_version)

      email = TestMailer.deliver_welcome(:mime_version => "1.0")
      assert_equal("1.0", email.mime_version)
    end
  end

  # def test_that_class_defaults_are_set_on_instantiation
  #   pending
  # end
  # 
  # def test_should_set_the_subject_from_i18n
  #   pending
  # end

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
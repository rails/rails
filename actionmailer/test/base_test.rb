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
class BaseTest < Test::Unit::TestCase
  
  class TestMailer < ActionMailer::Base
    
    def welcome(hash = {})
      headers['X-SPAM'] = "Not SPAM"
      hash = {:to => 'mikel@test.lindsaar.net', :from => 'jose@test.plataformatec.com',
              :subject => 'The first email on new API!'}.merge!(hash)
      mail(hash)
    end
    
  end

  def test_the_method_call_to_mail_does_not_raise_error
    assert_nothing_raised { TestMailer.deliver_welcome }
  end

  def test_should_set_the_headers_of_the_mail_message
    email = TestMailer.deliver_welcome
    assert_equal(email.to,      ['mikel@test.lindsaar.net'])
    assert_equal(email.from,    ['jose@test.plataformatec.com'])
    assert_equal(email.subject, 'The first email on new API!')
  end
  
  def test_should_allow_all_headers_set
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

#  def test_should_allow_custom_headers_to_be_set
#    email = TestMailer.deliver_welcome
#    assert_equal("Not SPAM", email['X-SPAM'])
#  end

  def test_should_use_class_defaults
    
  end

  # def test_that_class_defaults_are_set_on_instantiation
  #   pending
  # end
  # 
  # def test_should_set_the_subject_from_i18n
  #   pending
  # end
  
end
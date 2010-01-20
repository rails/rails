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
#      headers["Reply-To"] = 'cancelations@example.com'
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

  def test_calling_mail_should_pass_the_header_hash_to_the_new_mail_object
    
  end

  def test_it_should_guard_against_old_api_if_mail_method_called
    
  end

  # def test_that_class_defaults_are_set_on_instantiation
  #   pending
  # end
  # 
  # def test_should_set_the_subject_from_i18n
  #   pending
  # end
  
end
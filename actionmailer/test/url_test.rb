require "#{File.dirname(__FILE__)}/abstract_unit"

class TestMailer < ActionMailer::Base
  
  default_url_options[:host] = 'www.basecamphq.com'
  
  def signed_up_with_url(recipient)
    @recipients   = recipient
    @subject      = "[Signed up] Welcome #{recipient}"
    @from         = "system@loudthinking.com"
    @sent_on      = Time.local(2004, 12, 12)

    @body["recipient"]   = recipient
    @body["welcome_url"] = url_for :host => "example.com", :controller => "welcome", :action => "greeting"
  end

  class <<self
    attr_accessor :received_body
  end

  def receive(mail)
    self.class.received_body = mail.body
  end
end

class ActionMailerUrlTest < Test::Unit::TestCase
  include ActionMailer::Quoting

  def encode( text, charset="utf-8" )
    quoted_printable( text, charset )
  end

  def new_mail( charset="utf-8" )
    mail = TMail::Mail.new
    mail.mime_version = "1.0"
    if charset
      mail.set_content_type "text", "plain", { "charset" => charset }
    end
    mail
  end

  def setup
    set_delivery_method :test
    ActionMailer::Base.perform_deliveries = true
    ActionMailer::Base.deliveries = []

    @recipient = 'test@localhost'
  end

  def teardown
    restore_delivery_method
  end

  def test_signed_up_with_url
    ActionController::Routing::Routes.draw do |map| 
      map.connect ':controller/:action/:id' 
      map.welcome 'welcome', :controller=>"foo", :action=>"bar"
    end

    expected = new_mail
    expected.to      = @recipient
    expected.subject = "[Signed up] Welcome #{@recipient}"
    expected.body    = "Hello there, \n\nMr. #{@recipient}. Please see our greeting at http://example.com/welcome/greeting http://www.basecamphq.com/welcome\n\n<img alt=\"Somelogo\" src=\"/images/somelogo.png\" />"
    expected.from    = "system@loudthinking.com"
    expected.date    = Time.local(2004, 12, 12)

    created = nil
    assert_nothing_raised { created = TestMailer.create_signed_up_with_url(@recipient) }
    assert_not_nil created
    assert_equal expected.encoded, created.encoded

    assert_nothing_raised { TestMailer.deliver_signed_up_with_url(@recipient) }
    assert_not_nil ActionMailer::Base.deliveries.first
    assert_equal expected.encoded, ActionMailer::Base.deliveries.first.encoded
  end
end
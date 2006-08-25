require "#{File.dirname(__FILE__)}/abstract_unit"

class MockSMTP
  def self.deliveries
    @@deliveries
  end

  def initialize
    @@deliveries = []
  end

  def sendmail(mail, from, to)
    @@deliveries << [mail, from, to]
  end
end

class Net::SMTP
  def self.start(*args)
    yield MockSMTP.new
  end
end

class TestMailer < ActionMailer::Base
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

class ActionMailerTest < Test::Unit::TestCase
  include ActionMailer::Quoting

  def encode( text, charset="utf-8" )
    quoted_printable( text, charset )
  end

  def new_mail( charset="utf-8" )
    mail = TMail::Mail.new
    if charset
      mail.set_content_type "text", "plain", { "charset" => charset }
    end
    mail
  end

  def setup
    ActionMailer::Base.delivery_method = :test
    ActionMailer::Base.perform_deliveries = true
    ActionMailer::Base.deliveries = []

    @recipient = 'test@localhost'
  end

  def test_signed_up_with_url
    ActionController::Routing::Routes.draw do |map| 
      map.connect ':controller/:action/:id' 
    end

    expected = new_mail
    expected.to      = @recipient
    expected.subject = "[Signed up] Welcome #{@recipient}"
    expected.body    = "Hello there, \n\nMr. #{@recipient}. Please see our greeting at http://example.com/welcome/greeting"
    expected.from    = "system@loudthinking.com"
    expected.date    = Time.local(2004, 12, 12)
    expected.mime_version = nil

    created = nil
    assert_nothing_raised { created = TestMailer.create_signed_up_with_url(@recipient) }
    assert_not_nil created
    assert_equal expected.encoded, created.encoded

    assert_nothing_raised { TestMailer.deliver_signed_up_with_url(@recipient) }
    assert_not_nil ActionMailer::Base.deliveries.first
    assert_equal expected.encoded, ActionMailer::Base.deliveries.first.encoded
  end
end
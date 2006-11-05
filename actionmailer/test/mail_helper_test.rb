require "#{File.dirname(__FILE__)}/abstract_unit"

module MailerHelper
  def person_name
    "Mr. Joe Person"
  end
end

class HelperMailer < ActionMailer::Base
  helper MailerHelper
  helper :example

  def use_helper(recipient)
    recipients recipient
    subject    "using helpers"
    from       "tester@example.com"
  end

  def use_example_helper(recipient)
    recipients recipient
    subject    "using helpers"
    from       "tester@example.com"
    self.body = { :text => "emphasize me!" }
  end

  def use_mail_helper(recipient)
    recipients recipient
    subject    "using mailing helpers"
    from       "tester@example.com"
    self.body = { :text => 
      "But soft! What light through yonder window breaks? It is the east, " +
      "and Juliet is the sun. Arise, fair sun, and kill the envious moon, " +
      "which is sick and pale with grief that thou, her maid, art far more " +
      "fair than she. Be not her maid, for she is envious! Her vestal " +
      "livery is but sick and green, and none but fools do wear it. Cast " +
      "it off!"
    }
  end

  def use_helper_method(recipient)
    recipients recipient
    subject    "using helpers"
    from       "tester@example.com"
    self.body = { :text => "emphasize me!" }
  end

  private

    def name_of_the_mailer_class
      self.class.name
    end
    helper_method :name_of_the_mailer_class
end

class MailerHelperTest < Test::Unit::TestCase
  def new_mail( charset="utf-8" )
    mail = TMail::Mail.new
    mail.set_content_type "text", "plain", { "charset" => charset } if charset
    mail
  end

  def setup
    ActionMailer::Base.delivery_method = :test
    ActionMailer::Base.perform_deliveries = true
    ActionMailer::Base.deliveries = []

    @recipient = 'test@localhost'
  end

  def test_use_helper
    mail = HelperMailer.create_use_helper(@recipient)
    assert_match %r{Mr. Joe Person}, mail.encoded
  end

  def test_use_example_helper
    mail = HelperMailer.create_use_example_helper(@recipient)
    assert_match %r{<em><strong><small>emphasize me!}, mail.encoded
  end

  def test_use_helper_method
    mail = HelperMailer.create_use_helper_method(@recipient)
    assert_match %r{HelperMailer}, mail.encoded
  end

  def test_use_mail_helper
    mail = HelperMailer.create_use_mail_helper(@recipient)
    assert_match %r{  But soft!}, mail.encoded
    assert_match %r{east, and\n  Juliet}, mail.encoded
  end
end


require "#{File.dirname(__FILE__)}/abstract_unit"

class RenderMailer < ActionMailer::Base
  def inline_template(recipient)
    recipients recipient
    subject    "using helpers"
    from       "tester@example.com"
    body       render(:inline => "Hello, <%= @world %>", :body => { :world => "Earth" })
  end

  def file_template(recipient)
    recipients recipient
    subject    "using helpers"
    from       "tester@example.com"
    body       render(:file => "signed_up", :body => { :recipient => recipient })
  end

  def initialize_defaults(method_name)
    super
    mailer_name "test_mailer"
  end
end

class FirstMailer < ActionMailer::Base
  def share(recipient)
    recipients recipient
    subject    "using helpers"
    from       "tester@example.com"
  end
end

class SecondMailer < ActionMailer::Base
  def share(recipient)
    recipients recipient
    subject    "using helpers"
    from       "tester@example.com"
  end
end

class RenderHelperTest < Test::Unit::TestCase
  def setup
    ActionMailer::Base.delivery_method = :test
    ActionMailer::Base.perform_deliveries = true
    ActionMailer::Base.deliveries = []

    @recipient = 'test@localhost'
  end

  def test_inline_template
    mail = RenderMailer.create_inline_template(@recipient)
    assert_equal "Hello, Earth", mail.body.strip
  end

  def test_file_template
    mail = RenderMailer.create_file_template(@recipient)
    assert_equal "Hello there, \n\nMr. test@localhost", mail.body.strip
  end
end

class FirstSecondHelperTest < Test::Unit::TestCase
  def setup
    ActionMailer::Base.delivery_method = :test
    ActionMailer::Base.perform_deliveries = true
    ActionMailer::Base.deliveries = []

    @recipient = 'test@localhost'
  end

  def test_ordering
    mail = FirstMailer.create_share(@recipient)
    assert_equal "first mail", mail.body.strip
    mail = SecondMailer.create_share(@recipient)
    assert_equal "second mail", mail.body.strip
    mail = FirstMailer.create_share(@recipient)
    assert_equal "first mail", mail.body.strip
    mail = SecondMailer.create_share(@recipient)
    assert_equal "second mail", mail.body.strip
  end
end

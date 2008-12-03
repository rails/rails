require 'abstract_unit'

class AutoLayoutMailer < ActionMailer::Base
  def hello(recipient)
    recipients recipient
    subject    "You have a mail"
    from       "tester@example.com"
  end

  def spam(recipient)
    recipients recipient
    subject    "You have a mail"
    from       "tester@example.com"
    body       render(:inline => "Hello, <%= @world %>", :layout => 'spam', :body => { :world => "Earth" })
  end

  def nolayout(recipient)
    recipients recipient
    subject    "You have a mail"
    from       "tester@example.com"
    body       render(:inline => "Hello, <%= @world %>", :layout => false, :body => { :world => "Earth" })
  end

  def multipart(recipient)
    recipients recipient
    subject    "You have a mail"
    from       "tester@example.com"
  end
end

class ExplicitLayoutMailer < ActionMailer::Base
  layout 'spam', :except => [:logout]

  def signup(recipient)
    recipients recipient
    subject    "You have a mail"
    from       "tester@example.com"
  end

  def logout(recipient)
    recipients recipient
    subject    "You have a mail"
    from       "tester@example.com"
  end
end

class LayoutMailerTest < Test::Unit::TestCase
  def setup
    set_delivery_method :test
    ActionMailer::Base.perform_deliveries = true
    ActionMailer::Base.deliveries = []

    @recipient = 'test@localhost'
  end

  def teardown
    restore_delivery_method
  end

  def test_should_pickup_default_layout
    mail = AutoLayoutMailer.create_hello(@recipient)
    assert_equal "Hello from layout Inside", mail.body.strip
  end

  def test_should_pickup_multipart_layout
    mail = AutoLayoutMailer.create_multipart(@recipient)
    assert_equal 2, mail.parts.size

    assert_equal 'text/plain', mail.parts.first.content_type
    assert_equal "text/plain layout - text/plain multipart", mail.parts.first.body

    assert_equal 'text/html', mail.parts.last.content_type
    assert_equal "Hello from layout text/html multipart", mail.parts.last.body
  end

  def test_should_pickup_layout_given_to_render
    mail = AutoLayoutMailer.create_spam(@recipient)
    assert_equal "Spammer layout Hello, Earth", mail.body.strip
  end

  def test_should_respect_layout_false
    mail = AutoLayoutMailer.create_nolayout(@recipient)
    assert_equal "Hello, Earth", mail.body.strip
  end

  def test_explicit_class_layout
    mail = ExplicitLayoutMailer.create_signup(@recipient)
    assert_equal "Spammer layout We do not spam", mail.body.strip
  end

  def test_explicit_layout_exceptions
    mail = ExplicitLayoutMailer.create_logout(@recipient)
    assert_equal "You logged out", mail.body.strip
  end
end

require 'abstract_unit'

class AutoLayoutMailer < ActionMailer::Base
  default to: 'test@localhost',
    subject: "You have a mail",
    from: "tester@example.com"

  def hello
    mail()
  end

  def spam
    @world = "Earth"
    mail(body: render(inline: "Hello, <%= @world %>", layout: 'spam'))
  end

  def nolayout
    @world = "Earth"
    mail(body: render(inline: "Hello, <%= @world %>", layout: false))
  end

  def multipart(type = nil)
    mail(content_type: type) do |format|
      format.text { render }
      format.html { render }
    end
  end
end

class ExplicitLayoutMailer < ActionMailer::Base
  layout 'spam', except: [:logout]

  default to: 'test@localhost',
    subject: "You have a mail",
    from: "tester@example.com"

  def signup
    mail()
  end

  def logout
    mail()
  end
end

class LayoutMailerTest < ActiveSupport::TestCase
  def setup
    set_delivery_method :test
    ActionMailer::Base.perform_deliveries = true
    ActionMailer::Base.deliveries.clear
  end

  def teardown
    restore_delivery_method
  end

  def test_should_pickup_default_layout
    mail = AutoLayoutMailer.hello
    assert_equal "Hello from layout Inside", mail.body.to_s.strip
  end

  def test_should_pickup_multipart_layout
    mail = AutoLayoutMailer.multipart
    assert_equal "multipart/alternative", mail.mime_type
    assert_equal 2, mail.parts.size

    assert_equal 'text/plain', mail.parts.first.mime_type
    assert_equal "text/plain layout - text/plain multipart", mail.parts.first.body.to_s

    assert_equal 'text/html', mail.parts.last.mime_type
    assert_equal "Hello from layout text/html multipart", mail.parts.last.body.to_s
  end

  def test_should_pickup_multipartmixed_layout
    mail = AutoLayoutMailer.multipart("multipart/mixed")
    assert_equal "multipart/mixed", mail.mime_type
    assert_equal 2, mail.parts.size

    assert_equal 'text/plain', mail.parts.first.mime_type
    assert_equal "text/plain layout - text/plain multipart", mail.parts.first.body.to_s

    assert_equal 'text/html', mail.parts.last.mime_type
    assert_equal "Hello from layout text/html multipart", mail.parts.last.body.to_s
  end

  def test_should_pickup_layout_given_to_render
    mail = AutoLayoutMailer.spam
    assert_equal "Spammer layout Hello, Earth", mail.body.to_s.strip
  end

  def test_should_respect_layout_false
    mail = AutoLayoutMailer.nolayout
    assert_equal "Hello, Earth", mail.body.to_s.strip
  end

  def test_explicit_class_layout
    mail = ExplicitLayoutMailer.signup
    assert_equal "Spammer layout We do not spam", mail.body.to_s.strip
  end

  def test_explicit_layout_exceptions
    mail = ExplicitLayoutMailer.logout
    assert_equal "You logged out", mail.body.to_s.strip
  end
end

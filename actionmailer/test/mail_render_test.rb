require 'abstract_unit'

class RenderMailer < ActionMailer::Base
  def inline_template(recipient)
    recipients recipient
    subject    "using helpers"
    from       "tester@example.com"

    @world = "Earth"
    render :inline => "Hello, <%= @world %>"
  end

  def file_template(recipient)
    recipients recipient
    subject    "using helpers"
    from       "tester@example.com"

    @recipient = recipient
    render :file => "templates/signed_up"
  end

  def implicit_body(recipient)
    recipients recipient
    subject    "using helpers"
    from       "tester@example.com"

    @recipient = recipient
    render :template => "templates/signed_up"
  end

  def rxml_template(recipient)
    recipients recipient
    subject    "rendering rxml template"
    from       "tester@example.com"
  end

  def included_subtemplate(recipient)
    recipients recipient
    subject    "Including another template in the one being rendered"
    from       "tester@example.com"
  end

  def mailer_accessor(recipient)
    recipients recipient
    subject    "Mailer Accessor"
    from       "tester@example.com"

    render :inline => "Look, <%= mailer.subject %>!"
  end

  def no_instance_variable(recipient)
    recipients recipient
    subject    "No Instance Variable"
    from       "tester@example.com"

    silence_warnings do
      render :inline => "Look, subject.nil? is <%= @subject.nil? %>!"
    end
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

# CHANGED: Those tests were changed because body returns an object now
# Instead of mail.body.strip, we should mail.body.to_s.strip
class RenderHelperTest < Test::Unit::TestCase
  def setup
    set_delivery_method :test
    ActionMailer::Base.perform_deliveries = true
    ActionMailer::Base.deliveries = []

    @recipient = 'test@localhost'
  end

  def teardown
    restore_delivery_method
  end

  def test_implicit_body
    mail = RenderMailer.create_implicit_body(@recipient)
    assert_equal "Hello there, \n\nMr. test@localhost", mail.body.to_s.strip
  end

  def test_inline_template
    mail = RenderMailer.create_inline_template(@recipient)
    assert_equal "Hello, Earth", mail.body.to_s.strip
  end

  def test_file_template
    mail = RenderMailer.create_file_template(@recipient)
    assert_equal "Hello there, \n\nMr. test@localhost", mail.body.to_s.strip
  end

  def test_rxml_template
    mail = RenderMailer.deliver_rxml_template(@recipient)
    assert_equal "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<test/>", mail.body.to_s.strip
  end

  def test_included_subtemplate
    mail = RenderMailer.deliver_included_subtemplate(@recipient)
    assert_equal "Hey Ho, let's go!", mail.body.to_s.strip
  end

  def test_mailer_accessor
    mail = RenderMailer.deliver_mailer_accessor(@recipient)
    assert_equal "Look, Mailer Accessor!", mail.body.to_s.strip
  end

  def test_no_instance_variable
    mail = RenderMailer.deliver_no_instance_variable(@recipient)
    assert_equal "Look, subject.nil? is true!", mail.body.to_s.strip
  end
end

class FirstSecondHelperTest < Test::Unit::TestCase
  def setup
    set_delivery_method :test
    ActionMailer::Base.perform_deliveries = true
    ActionMailer::Base.deliveries = []

    @recipient = 'test@localhost'
  end

  def teardown
    restore_delivery_method
  end

  def test_ordering
    mail = FirstMailer.create_share(@recipient)
    assert_equal "first mail", mail.body.to_s.strip
    mail = SecondMailer.create_share(@recipient)
    assert_equal "second mail", mail.body.to_s.strip
    mail = FirstMailer.create_share(@recipient)
    assert_equal "first mail", mail.body.to_s.strip
    mail = SecondMailer.create_share(@recipient)
    assert_equal "second mail", mail.body.to_s.strip
  end
end

require 'abstract_unit'

class RenderMailer < ActionMailer::Base
  def inline_template
    recipients 'test@localhost'
    subject    "using helpers"
    from       "tester@example.com"

    @world = "Earth"
    body       render(:inline => "Hello, <%= @world %>")
  end

  def file_template
    recipients 'test@localhost'
    subject    "using helpers"
    from       "tester@example.com"

    @recipient = 'test@localhost'
    body       render(:file => "templates/signed_up")
  end

  def no_instance_variable
    recipients 'test@localhost'
    subject    "No Instance Variable"
    from       "tester@example.com"

    silence_warnings do
      body render(:inline => "Look, subject.nil? is <%= @subject.nil? %>!")
    end
  end

  def multipart_alternative
    recipients 'test@localhost'
    subject    'multipart/alternative'
    from       'tester@example.com'

    build_multipart_message(:foo => "bar")
  end

  private
    def build_multipart_message(assigns = {})
      content_type "multipart/alternative"

      part "text/plain" do |p|
        p.body = build_body_part('plain', assigns, :layout => false)
      end

      part "text/html" do |p|
        p.body = build_body_part('html', assigns)
      end
    end

    def build_body_part(content_type, assigns, options = {})
      ActiveSupport::Deprecation.silence do
        render "#{template}.#{content_type}", :body => assigns
      end
    end
end

class FirstMailer < ActionMailer::Base
  def share
    recipients 'test@localhost'
    subject    "using helpers"
    from       "tester@example.com"
  end
end

class SecondMailer < ActionMailer::Base
  def share
    recipients 'test@localhost'
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
    ActionMailer::Base.deliveries.clear
    ActiveSupport::Deprecation.silenced = true

    @recipient = 'test@localhost'
  end

  def teardown
    ActiveSupport::Deprecation.silenced = false
    restore_delivery_method
  end

  def test_inline_template
    mail = RenderMailer.inline_template
    assert_equal "Hello, Earth", mail.body.to_s.strip
  end

  def test_file_template
    mail = RenderMailer.file_template
    assert_equal "Hello there,\n\nMr. test@localhost", mail.body.to_s.strip
  end

  def test_no_instance_variable
    mail = RenderMailer.no_instance_variable.deliver
    assert_equal "Look, subject.nil? is true!", mail.body.to_s.strip
  end
end

class FirstSecondHelperTest < Test::Unit::TestCase
  def setup
    set_delivery_method :test
    ActiveSupport::Deprecation.silenced = true
    ActionMailer::Base.perform_deliveries = true
    ActionMailer::Base.deliveries.clear

    @recipient = 'test@localhost'
  end

  def teardown
    ActiveSupport::Deprecation.silenced = false
    restore_delivery_method
  end

  def test_ordering
    mail = FirstMailer.share
    assert_equal "first mail", mail.body.to_s.strip
    mail = SecondMailer.share
    assert_equal "second mail", mail.body.to_s.strip
    mail = FirstMailer.share
    assert_equal "first mail", mail.body.to_s.strip
    mail = SecondMailer.share
    assert_equal "second mail", mail.body.to_s.strip
  end
end

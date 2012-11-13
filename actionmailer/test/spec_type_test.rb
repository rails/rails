require 'abstract_unit'

class NotificationMailer < ActionMailer::Base; end
class Notifications < ActionMailer::Base; end

class SpecTypeTest < ActiveSupport::TestCase
  def assert_mailer actual
    assert_equal ActionMailer::TestCase, actual
  end

  def refute_mailer actual
    refute_equal ActionMailer::TestCase, actual
  end

  def test_spec_type_resolves_for_class_constants
    assert_mailer MiniTest::Spec.spec_type(NotificationMailer)
    assert_mailer MiniTest::Spec.spec_type(Notifications)
  end

  def test_spec_type_resolves_for_matching_strings
    assert_mailer MiniTest::Spec.spec_type("WidgetMailer")
    assert_mailer MiniTest::Spec.spec_type("WidgetMailerTest")
    assert_mailer MiniTest::Spec.spec_type("Widget Mailer Test")
    # And is not case sensitive
    assert_mailer MiniTest::Spec.spec_type("widgetmailer")
    assert_mailer MiniTest::Spec.spec_type("widgetmailertest")
    assert_mailer MiniTest::Spec.spec_type("widget mailer test")
  end

  def test_spec_type_wont_match_non_space_characters
    refute_mailer MiniTest::Spec.spec_type("Widget Mailer\tTest")
    refute_mailer MiniTest::Spec.spec_type("Widget Mailer\rTest")
    refute_mailer MiniTest::Spec.spec_type("Widget Mailer\nTest")
    refute_mailer MiniTest::Spec.spec_type("Widget Mailer\fTest")
    refute_mailer MiniTest::Spec.spec_type("Widget MailerXTest")
  end
end

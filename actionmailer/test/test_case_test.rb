require "abstract_unit"

class TestTestMailer < ActionMailer::Base
end

class ClearTestDeliveriesMixinTest < ActiveSupport::TestCase
  include ActionMailer::TestCase::ClearTestDeliveries

  def before_setup
    ActionMailer::Base.delivery_method, @original_delivery_method = :test, ActionMailer::Base.delivery_method
    ActionMailer::Base.deliveries << "better clear me, setup"
    super
  end

  def after_teardown
    super
    assert_equal [], ActionMailer::Base.deliveries
    ActionMailer::Base.delivery_method = @original_delivery_method
  end

  def test_deliveries_are_cleared_on_setup_and_teardown
    assert_equal [], ActionMailer::Base.deliveries
    ActionMailer::Base.deliveries << "better clear me, teardown"
  end
end

class MailerDeliveriesClearingTest < ActionMailer::TestCase
  def before_setup
    ActionMailer::Base.deliveries << "better clear me, setup"
    super
  end

  def after_teardown
    super
    assert_equal [], ActionMailer::Base.deliveries
  end

  def test_deliveries_are_cleared_on_setup_and_teardown
    assert_equal [], ActionMailer::Base.deliveries
    ActionMailer::Base.deliveries << "better clear me, teardown"
  end
end

class CrazyNameMailerTest < ActionMailer::TestCase
  tests TestTestMailer

  def test_set_mailer_class_manual
    assert_equal TestTestMailer, self.class.mailer_class
  end
end

class CrazySymbolNameMailerTest < ActionMailer::TestCase
  tests :test_test_mailer

  def test_set_mailer_class_manual_using_symbol
    assert_equal TestTestMailer, self.class.mailer_class
  end
end

class CrazyStringNameMailerTest < ActionMailer::TestCase
  tests "test_test_mailer"

  def test_set_mailer_class_manual_using_string
    assert_equal TestTestMailer, self.class.mailer_class
  end
end

require 'abstract_unit'

class DefaultDeliveryMethodMailer < ActionMailer::Base
end

class NonDefaultDeliveryMethodMailer < ActionMailer::Base
  self.delivery_method = :sendmail
end

class ActionMailerBase_delivery_method_Test < Test::Unit::TestCase
  def setup
    set_delivery_method :smtp
  end
  
  def teardown
    restore_delivery_method
  end

  def test_should_be_the_default_smtp
    assert_equal :smtp, ActionMailer::Base.delivery_method
  end
end

class DefaultDeliveryMethodMailer_delivery_method_Test < Test::Unit::TestCase
  def setup
    set_delivery_method :smtp
  end
  
  def teardown
    restore_delivery_method
  end
  
  def test_should_be_the_default_smtp
    assert_equal :smtp, DefaultDeliveryMethodMailer.delivery_method
  end
end

class NonDefaultDeliveryMethodMailer_delivery_method_Test < Test::Unit::TestCase
  def setup
    set_delivery_method :smtp
  end
  
  def teardown
    restore_delivery_method
  end

  def test_should_be_the_set_delivery_method
    assert_equal :sendmail, NonDefaultDeliveryMethodMailer.delivery_method
  end
end


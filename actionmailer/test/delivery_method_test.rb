require 'abstract_unit'
require 'mail'

class DefaultDeliveryMethodMailer < ActionMailer::Base
end

class NonDefaultDeliveryMethodMailer < ActionMailer::Base
  self.delivery_method = :sendmail
end

class FileDeliveryMethodMailer < ActionMailer::Base
  self.delivery_method = :file
end

class CustomDeliveryMethod

  def initialize(values)
    @custom_deliveries = []
  end

  attr_accessor :custom_deliveries
  
  attr_accessor :settings
  
  def deliver!(mail)
    self.custom_deliveries << mail
  end
end

class CustomerDeliveryMailer < ActionMailer::Base
  self.delivery_method = CustomDeliveryMethod
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

  def test_should_have_default_smtp_delivery_method_settings
    settings = { :address              => "localhost",
                 :port                 => 25,
                 :domain               => 'localhost.localdomain',
                 :user_name            => nil,
                 :password             => nil,
                 :authentication       => nil,
                 :enable_starttls_auto => true }
    assert_equal settings, ActionMailer::Base.smtp_settings
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

  def test_should_have_default_smtp_delivery_method_settings
    settings = { :address              => "localhost",
                 :port                 => 25,
                 :domain               => 'localhost.localdomain',
                 :user_name            => nil,
                 :password             => nil,
                 :authentication       => nil,
                 :enable_starttls_auto => true }
    assert_equal settings, DefaultDeliveryMethodMailer.smtp_settings
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

  def test_should_have_default_sendmail_delivery_method_settings
    settings = {:location       => '/usr/sbin/sendmail',
                :arguments      => '-i -t'}
    assert_equal settings, NonDefaultDeliveryMethodMailer.sendmail_settings
  end
end

class FileDeliveryMethodMailer_delivery_method_Test < Test::Unit::TestCase
  def setup
    set_delivery_method :smtp
  end

  def teardown
    restore_delivery_method
  end

  def test_should_be_the_set_delivery_method
    assert_equal :file, FileDeliveryMethodMailer.delivery_method
  end

  def test_should_have_default_file_delivery_method_settings
    settings = {:location => "#{Dir.tmpdir}/mails"}
    assert_equal settings, FileDeliveryMethodMailer.file_settings
  end
end

class CustomDeliveryMethodMailer_delivery_method_Test < Test::Unit::TestCase
  def setup
    set_delivery_method :smtp
  end

  def teardown
    restore_delivery_method
  end

  def test_should_be_the_set_delivery_method
    assert_equal CustomDeliveryMethod, CustomerDeliveryMailer.delivery_method
  end

  def test_should_have_default_custom_delivery_method_settings
    settings = {}
    assert_equal settings, CustomerDeliveryMailer.custom_settings
  end
end

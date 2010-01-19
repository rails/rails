require 'abstract_unit'
require 'mail'

class MyCustomDelivery
end

class DefaultsDeliveryMethodsTest < ActionMailer::TestCase
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

  def test_should_have_default_file_delivery_method_settings
    settings = {:location => "#{Dir.tmpdir}/mails"}
    assert_equal settings, ActionMailer::Base.file_settings
  end

  def test_should_have_default_sendmail_delivery_method_settings
    settings = {:location       => '/usr/sbin/sendmail',
                :arguments      => '-i -t'}
    assert_equal settings, ActionMailer::Base.sendmail_settings
  end
end

class CustomDeliveryMethodsTest < ActionMailer::TestCase
  def setup
    ActionMailer::Base.add_delivery_method :custom, MyCustomDelivery
  end

  def teardown
    ActionMailer::Base.delivery_methods.delete(:custom)
    ActionMailer::Base.delivery_settings.delete(:custom)
  end

  def test_allow_to_add_a_custom_delivery_method
    ActionMailer::Base.delivery_method = :custom
    assert_equal :custom, ActionMailer::Base.delivery_method
  end

  def test_allow_to_customize_custom_settings
    ActionMailer::Base.custom_settings = { :foo => :bar }
    assert_equal Hash[:foo => :bar], ActionMailer::Base.custom_settings
  end

  def test_respond_to_custom_method_settings
    assert_respond_to ActionMailer::Base, :custom_settings
    assert_respond_to ActionMailer::Base, :custom_settings=
  end

  def test_should_not_respond_for_invalid_method_settings
    assert_raise NoMethodError do
      ActionMailer::Base.another_settings
    end
  end
end

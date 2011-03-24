require 'abstract_unit'
require 'mail'

class MyCustomDelivery
end

class BogusDelivery
  def initialize(*)
  end

  def deliver!(mail)
    raise "failed"
  end
end

class DefaultsDeliveryMethodsTest < ActiveSupport::TestCase
  test "default smtp settings" do
    settings = { :address              => "localhost",
                 :port                 => 25,
                 :domain               => 'localhost.localdomain',
                 :user_name            => nil,
                 :password             => nil,
                 :authentication       => nil,
                 :enable_starttls_auto => true }
    assert_equal settings, ActionMailer::Base.smtp_settings
  end

  test "default file delivery settings" do
    settings = {:location => "#{Dir.tmpdir}/mails"}
    assert_equal settings, ActionMailer::Base.file_settings
  end

  test "default sendmail settings" do
    settings = {:location       => '/usr/sbin/sendmail',
                :arguments      => '-i -t'}
    assert_equal settings, ActionMailer::Base.sendmail_settings
  end
end

class CustomDeliveryMethodsTest < ActiveSupport::TestCase
  def setup
    @old_delivery_method = ActionMailer::Base.delivery_method
    ActionMailer::Base.add_delivery_method :custom, MyCustomDelivery
  end

  def teardown
    ActionMailer::Base.delivery_method = @old_delivery_method
    new = ActionMailer::Base.delivery_methods.dup
    new.delete(:custom)
    ActionMailer::Base.delivery_methods = new
  end

  test "allow to add custom delivery method" do
    ActionMailer::Base.delivery_method = :custom
    assert_equal :custom, ActionMailer::Base.delivery_method
  end

  test "allow to customize custom settings" do
    ActionMailer::Base.custom_settings = { :foo => :bar }
    assert_equal Hash[:foo => :bar], ActionMailer::Base.custom_settings
  end

  test "respond to custom settings" do
    assert_respond_to ActionMailer::Base, :custom_settings
    assert_respond_to ActionMailer::Base, :custom_settings=
  end

  test "does not respond to unknown settings" do
    assert_raise NoMethodError do
      ActionMailer::Base.another_settings
    end
  end
end

class MailDeliveryTest < ActiveSupport::TestCase
  class DeliveryMailer < ActionMailer::Base
    DEFAULT_HEADERS = {
      :to => 'mikel@test.lindsaar.net',
      :from => 'jose@test.plataformatec.com'
    }

    def welcome(hash={})
      mail(DEFAULT_HEADERS.merge(hash))
    end
  end

  def setup
    ActionMailer::Base.delivery_method = :smtp
  end

  def teardown
    DeliveryMailer.delivery_method = :smtp
    DeliveryMailer.perform_deliveries = true
    DeliveryMailer.raise_delivery_errors = true
  end

  test "ActionMailer should be told when Mail gets delivered" do
    DeliveryMailer.deliveries.clear
    DeliveryMailer.expects(:deliver_mail).once
    DeliveryMailer.welcome.deliver
  end

  test "delivery method can be customized per instance" do
    email = DeliveryMailer.welcome.deliver
    assert_instance_of Mail::SMTP, email.delivery_method
    email = DeliveryMailer.welcome(:delivery_method => :test).deliver
    assert_instance_of Mail::TestMailer, email.delivery_method
  end

  test "delivery method can be customized in subclasses not changing the parent" do
    DeliveryMailer.delivery_method = :test
    assert_equal :smtp, ActionMailer::Base.delivery_method
    $BREAK = true
    email = DeliveryMailer.welcome.deliver
    assert_instance_of Mail::TestMailer, email.delivery_method
  end

  test "non registered delivery methods raises errors" do
    DeliveryMailer.delivery_method = :unknown
    assert_raise RuntimeError do
      DeliveryMailer.welcome.deliver
    end
  end

  test "does not perform deliveries if requested" do
    DeliveryMailer.perform_deliveries = false
    DeliveryMailer.deliveries.clear
    Mail::Message.any_instance.expects(:deliver!).never
    DeliveryMailer.welcome.deliver
  end

  test "does not append the deliveries collection if told not to perform the delivery" do
    DeliveryMailer.perform_deliveries = false
    DeliveryMailer.deliveries.clear
    DeliveryMailer.welcome.deliver
    assert_equal(0, DeliveryMailer.deliveries.length)
  end

  test "raise errors on bogus deliveries" do
    DeliveryMailer.delivery_method = BogusDelivery
    DeliveryMailer.deliveries.clear
    assert_raise RuntimeError do
      DeliveryMailer.welcome.deliver
    end
  end

  test "does not increment the deliveries collection on error" do
    DeliveryMailer.delivery_method = BogusDelivery
    DeliveryMailer.deliveries.clear
    assert_raise RuntimeError do
      DeliveryMailer.welcome.deliver
    end
    assert_equal(0, DeliveryMailer.deliveries.length)
  end

  test "does not raise errors on bogus deliveries if set" do
    DeliveryMailer.delivery_method = BogusDelivery
    DeliveryMailer.raise_delivery_errors = false
    assert_nothing_raised do
      DeliveryMailer.welcome.deliver
    end
  end

  test "does not increment the deliveries collection on bogus deliveries" do
    DeliveryMailer.delivery_method = BogusDelivery
    DeliveryMailer.raise_delivery_errors = false
    DeliveryMailer.deliveries.clear
    DeliveryMailer.welcome.deliver
    assert_equal(0, DeliveryMailer.deliveries.length)
  end

end

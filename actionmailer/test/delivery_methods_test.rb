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
    ActionMailer::Base.delivery_methods.delete(:custom)
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
  class DeliverMail < ActionMailer::Base
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
    DeliverMail.delivery_method = :smtp
    DeliverMail.perform_deliveries = true
    DeliverMail.raise_delivery_errors = true
  end

  test "ActionMailer should be told when Mail gets delivered" do
    DeliverMail.deliveries.clear
    DeliverMail.expects(:delivered_email).once
    DeliverMail.welcome.deliver
    assert_equal(1, DeliverMail.deliveries.length)
  end

  test "delivery method can be customized per instance" do
    email = DeliverMail.welcome.deliver
    assert_instance_of Mail::SMTP, email.delivery_method
    email = DeliverMail.welcome(:delivery_method => :test).deliver
    assert_instance_of Mail::TestMailer, email.delivery_method
  end

  test "delivery method can be customized in subclasses not changing the parent" do
    DeliverMail.delivery_method = :test
    assert_equal :smtp, ActionMailer::Base.delivery_method
    $BREAK = true
    email = DeliverMail.welcome.deliver
    assert_instance_of Mail::TestMailer, email.delivery_method
  end

  test "non registered delivery methods raises errors" do
    DeliverMail.delivery_method = :unknown
    assert_raise RuntimeError do
      DeliverMail.welcome.deliver
    end
  end

  test "does not perform deliveries if requested" do
    DeliverMail.perform_deliveries = false
    DeliverMail.deliveries.clear
    DeliverMail.expects(:delivered_email).never
    DeliverMail.welcome.deliver
    assert_equal(0, DeliverMail.deliveries.length)
  end

  test "raise errors on bogus deliveries" do
    DeliverMail.delivery_method = BogusDelivery
    DeliverMail.deliveries.clear
    DeliverMail.expects(:delivered_email).never
    assert_raise RuntimeError do
      DeliverMail.welcome.deliver
    end
    assert_equal(0, DeliverMail.deliveries.length)
  end

  test "does not raise errors on bogus deliveries if set" do
    DeliverMail.delivery_method = BogusDelivery
    DeliverMail.raise_delivery_errors = false
    DeliverMail.deliveries.clear
    DeliverMail.expects(:delivered_email).once
    DeliverMail.welcome.deliver
    assert_equal(1, DeliverMail.deliveries.length)
  end
end
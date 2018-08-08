# frozen_string_literal: true

require "abstract_unit"

class MyCustomDelivery
end

class MyOptionedDelivery
  attr_reader :options
  def initialize(options)
    @options = options
  end
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
    settings = { address:              "localhost",
                 port:                 25,
                 domain:               "localhost.localdomain",
                 user_name:            nil,
                 password:             nil,
                 authentication:       nil,
                 enable_starttls_auto: true }
    assert_equal settings, ActionMailer::Base.smtp_settings
  end

  test "default file delivery settings (with Rails.root)" do
    settings = { location: "#{Rails.root}/tmp/mails" }
    assert_equal settings, ActionMailer::Base.file_settings
  end

  test "default sendmail settings" do
    settings = {
      location:  "/usr/sbin/sendmail",
      arguments: "-i"
    }
    assert_equal settings, ActionMailer::Base.sendmail_settings
  end
end

class CustomDeliveryMethodsTest < ActiveSupport::TestCase
  setup do
    @old_delivery_method = ActionMailer::Base.delivery_method
    ActionMailer::Base.add_delivery_method :custom, MyCustomDelivery
  end

  teardown do
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
    ActionMailer::Base.custom_settings = { foo: :bar }
    assert_equal Hash[foo: :bar], ActionMailer::Base.custom_settings
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
      to: "mikel@test.lindsaar.net",
      from: "jose@test.plataformatec.com"
    }

    def welcome(hash = {})
      mail(DEFAULT_HEADERS.merge(hash))
    end
  end

  setup do
    @old_delivery_method = DeliveryMailer.delivery_method
  end

  teardown do
    DeliveryMailer.delivery_method = @old_delivery_method
    DeliveryMailer.deliveries.clear
  end

  test "ActionMailer should be told when Mail gets delivered" do
    DeliveryMailer.delivery_method = :test
    assert_called(DeliveryMailer, :deliver_mail) do
      DeliveryMailer.welcome.deliver_now
    end
  end

  test "delivery method can be customized per instance" do
    stub_any_instance(Mail::SMTP, instance: Mail::SMTP.new({})) do |instance|
      assert_called(instance, :deliver!) do
        email = DeliveryMailer.welcome.deliver_now
        assert_instance_of Mail::SMTP, email.delivery_method
        email = DeliveryMailer.welcome(delivery_method: :test).deliver_now
        assert_instance_of Mail::TestMailer, email.delivery_method
      end
    end
  end

  test "delivery method can be customized in subclasses not changing the parent" do
    DeliveryMailer.delivery_method = :test
    assert_equal :smtp, ActionMailer::Base.delivery_method
    email = DeliveryMailer.welcome.deliver_now
    assert_instance_of Mail::TestMailer, email.delivery_method
  end

  test "delivery method options default to class level options" do
    default_options = { a: "b" }
    ActionMailer::Base.add_delivery_method :optioned, MyOptionedDelivery, default_options
    mail_instance = DeliveryMailer.welcome(delivery_method: :optioned)
    assert_equal default_options, mail_instance.delivery_method.options
  end

  test "delivery method options can be overridden per mail instance" do
    default_options = { a: "b" }
    ActionMailer::Base.add_delivery_method :optioned, MyOptionedDelivery, default_options
    overridden_options = { a: "a" }
    mail_instance = DeliveryMailer.welcome(delivery_method: :optioned, delivery_method_options: overridden_options)
    assert_equal overridden_options, mail_instance.delivery_method.options
  end

  test "default delivery options can be overridden per mail instance" do
    settings = {
      address: "localhost",
      port: 25,
      domain: "localhost.localdomain",
      user_name: nil,
      password: nil,
      authentication: nil,
      enable_starttls_auto: true
    }
    assert_equal settings, ActionMailer::Base.smtp_settings
    overridden_options = { user_name: "overridden", password: "somethingobtuse" }
    mail_instance = DeliveryMailer.welcome(delivery_method_options: overridden_options)
    delivery_method_instance = mail_instance.delivery_method
    assert_equal "overridden", delivery_method_instance.settings[:user_name]
    assert_equal "somethingobtuse", delivery_method_instance.settings[:password]
    assert_equal delivery_method_instance.settings.merge(overridden_options), delivery_method_instance.settings

    # make sure that overriding delivery method options per mail instance doesn't affect the Base setting
    assert_equal settings, ActionMailer::Base.smtp_settings
  end

  test "non registered delivery methods raises errors" do
    DeliveryMailer.delivery_method = :unknown
    error = assert_raise RuntimeError do
      DeliveryMailer.welcome.deliver_now
    end
    assert_equal "Invalid delivery method :unknown", error.message
  end

  test "undefined delivery methods raises errors" do
    DeliveryMailer.delivery_method = nil
    error = assert_raise RuntimeError do
      DeliveryMailer.welcome.deliver_now
    end
    assert_equal "Delivery method cannot be nil", error.message
  end

  test "does not perform deliveries if requested" do
    old_perform_deliveries = DeliveryMailer.perform_deliveries
    begin
      DeliveryMailer.perform_deliveries = false
      stub_any_instance(Mail::Message) do |instance|
        assert_not_called(instance, :deliver!) do
          DeliveryMailer.welcome.deliver_now
        end
      end
    ensure
      DeliveryMailer.perform_deliveries = old_perform_deliveries
    end
  end

  test "does not append the deliveries collection if told not to perform the delivery" do
    old_perform_deliveries = DeliveryMailer.perform_deliveries
    begin
      DeliveryMailer.perform_deliveries = false
      DeliveryMailer.welcome.deliver_now
      assert_equal [], DeliveryMailer.deliveries
    ensure
      DeliveryMailer.perform_deliveries = old_perform_deliveries
    end
  end

  test "raise errors on bogus deliveries" do
    DeliveryMailer.delivery_method = BogusDelivery
    assert_raise RuntimeError do
      DeliveryMailer.welcome.deliver_now
    end
  end

  test "does not increment the deliveries collection on error" do
    DeliveryMailer.delivery_method = BogusDelivery
    assert_raise RuntimeError do
      DeliveryMailer.welcome.deliver_now
    end
    assert_equal [], DeliveryMailer.deliveries
  end

  test "does not raise errors on bogus deliveries if set" do
    old_raise_delivery_errors = DeliveryMailer.raise_delivery_errors
    begin
      DeliveryMailer.delivery_method = BogusDelivery
      DeliveryMailer.raise_delivery_errors = false
      assert_nothing_raised do
        DeliveryMailer.welcome.deliver_now
      end
    ensure
      DeliveryMailer.raise_delivery_errors = old_raise_delivery_errors
    end
  end

  test "does not increment the deliveries collection on bogus deliveries" do
    old_raise_delivery_errors = DeliveryMailer.raise_delivery_errors
    begin
      DeliveryMailer.delivery_method = BogusDelivery
      DeliveryMailer.raise_delivery_errors = false
      DeliveryMailer.welcome.deliver_now
      assert_equal [], DeliveryMailer.deliveries
    ensure
      DeliveryMailer.raise_delivery_errors = old_raise_delivery_errors
    end
  end
end

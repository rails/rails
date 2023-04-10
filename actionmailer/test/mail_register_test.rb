# frozen_string_literal: true

require "abstract_unit"
require "mailers/base_mailer"

class MailRegisterTest < ActiveSupport::TestCase
  setup do
    @original_delivery_method = ActionMailer::Base.delivery_method
    ActionMailer::Base.delivery_method = :test
    @original_asset_host = ActionMailer::Base.asset_host
    @original_assets_dir = ActionMailer::Base.assets_dir
  end

  teardown do
    ActionMailer::Base.asset_host = @original_asset_host
    ActionMailer::Base.assets_dir = @original_assets_dir
    BaseMailer.deliveries.clear
    ActionMailer::Base.delivery_method = @original_delivery_method
  end

  # Before and After hooks

  class MyObserver
    def self.delivered_email(mail)
    end
  end

  class MySecondObserver
    def self.delivered_email(mail)
    end
  end

  test "you can register and unregister an observer to the mail object that gets informed on email delivery" do
    mail_side_effects do
      ActionMailer::Base.register_observer(MyObserver)
      mail = BaseMailer.welcome
      assert_called_with(MyObserver, :delivered_email, [mail]) do
        mail.deliver_now
      end

      ActionMailer::Base.unregister_observer(MyObserver)
      assert_not_called(MyObserver, :delivered_email, returns: mail) do
        mail.deliver_now
      end
    end
  end

  test "you can register and unregister an observer using its stringified name to the mail object that gets informed on email delivery" do
    mail_side_effects do
      ActionMailer::Base.register_observer("MailRegisterTest::MyObserver")
      mail = BaseMailer.welcome
      assert_called_with(MyObserver, :delivered_email, [mail]) do
        mail.deliver_now
      end

      ActionMailer::Base.unregister_observer("MailRegisterTest::MyObserver")
      assert_not_called(MyObserver, :delivered_email, returns: mail) do
        mail.deliver_now
      end
    end
  end

  test "you can register and unregister an observer using its symbolized underscored name to the mail object that gets informed on email delivery" do
    mail_side_effects do
      ActionMailer::Base.register_observer(:"mail_register_test/my_observer")
      mail = BaseMailer.welcome
      assert_called_with(MyObserver, :delivered_email, [mail]) do
        mail.deliver_now
      end

      ActionMailer::Base.unregister_observer(:"mail_register_test/my_observer")
      assert_not_called(MyObserver, :delivered_email, returns: mail) do
        mail.deliver_now
      end
    end
  end

  test "you can register and unregister multiple observers to the mail object that both get informed on email delivery" do
    mail_side_effects do
      ActionMailer::Base.register_observers("MailRegisterTest::MyObserver", MySecondObserver)
      mail = BaseMailer.welcome
      assert_called_with(MyObserver, :delivered_email, [mail]) do
        assert_called_with(MySecondObserver, :delivered_email, [mail]) do
          mail.deliver_now
        end
      end

      ActionMailer::Base.unregister_observers("MailRegisterTest::MyObserver", MySecondObserver)
      assert_not_called(MyObserver, :delivered_email, returns: mail) do
        mail.deliver_now
      end
      assert_not_called(MySecondObserver, :delivered_email, returns: mail) do
        mail.deliver_now
      end
    end
  end

  test "you can register an observer for only a specific mailer" do
    mail_side_effects do
      inherited_mailer = Class.new(BaseMailer) do
        def welcome
          mail
        end
      end

      inherited_mailer.register_observer(MyObserver)
      mail = inherited_mailer.welcome
      assert_called_with(MyObserver, :delivered_email, [mail]) do
        mail.deliver_now
      end

      mail = BaseMailer.welcome
      assert_not_called(MyObserver, :delivered_email, returns: mail) do
        mail.deliver_now
      end
    end
  end

  test "you can register an observer and it will only apply for inherited mailers" do
    mail_side_effects do
      inherited_mailer = Class.new(BaseMailer)
      inherited_child_mailer = Class.new(inherited_mailer) do
        def welcome
          mail
        end
      end

      inherited_mailer.register_observer(MyObserver)
      mail = inherited_child_mailer.welcome
      assert_called_with(MyObserver, :delivered_email, [mail]) do
        mail.deliver_now
      end

      mail = BaseMailer.welcome
      assert_not_called(MyObserver, :delivered_email, [mail]) do
        mail.deliver_now
      end
    end
  end

  test "you can unregister an observer only via the registered class" do
    mail_side_effects do
      BaseMailer.register_observer(MyObserver)
      mail = BaseMailer.welcome
      assert_called_with(MyObserver, :delivered_email, [mail]) do
        mail.deliver_now
      end

      ActionMailer::Base.unregister_observer(MyObserver)
      assert_called_with(MyObserver, :delivered_email, [mail]) do
        mail.deliver_now
      end

      BaseMailer.unregister_observer(MyObserver)
      assert_not_called(MyObserver, :delivered_email, returns: mail) do
        mail.deliver_now
      end
    end
  end

  class MyInterceptor
    def self.delivering_email(mail); end
    def self.previewing_email(mail); end
  end

  class MySecondInterceptor
    def self.delivering_email(mail); end
    def self.previewing_email(mail); end
  end

  test "you can register and unregister an interceptor to the mail object that gets passed the mail object before delivery" do
    mail_side_effects do
      ActionMailer::Base.register_interceptor(MyInterceptor)
      mail = BaseMailer.welcome
      assert_called_with(MyInterceptor, :delivering_email, [mail]) do
        mail.deliver_now
      end

      ActionMailer::Base.unregister_interceptor(MyInterceptor)
      assert_not_called(MyInterceptor, :delivering_email, returns: mail) do
        mail.deliver_now
      end
    end
  end

  test "you can register and unregister an interceptor using its stringified name to the mail object that gets passed the mail object before delivery" do
    mail_side_effects do
      ActionMailer::Base.register_interceptor("MailRegisterTest::MyInterceptor")
      mail = BaseMailer.welcome
      assert_called_with(MyInterceptor, :delivering_email, [mail]) do
        mail.deliver_now
      end

      ActionMailer::Base.unregister_interceptor("MailRegisterTest::MyInterceptor")
      assert_not_called(MyInterceptor, :delivering_email, returns: mail) do
        mail.deliver_now
      end
    end
  end

  test "you can register and unregister an interceptor using its symbolized underscored name to the mail object that gets passed the mail object before delivery" do
    mail_side_effects do
      ActionMailer::Base.register_interceptor(:"mail_register_test/my_interceptor")
      mail = BaseMailer.welcome
      assert_called_with(MyInterceptor, :delivering_email, [mail]) do
        mail.deliver_now
      end

      ActionMailer::Base.unregister_interceptor(:"mail_register_test/my_interceptor")
      assert_not_called(MyInterceptor, :delivering_email, returns: mail) do
        mail.deliver_now
      end
    end
  end

  test "you can register and unregister multiple interceptors to the mail object that both get passed the mail object before delivery" do
    mail_side_effects do
      ActionMailer::Base.register_interceptors("MailRegisterTest::MyInterceptor", MySecondInterceptor)
      mail = BaseMailer.welcome
      assert_called_with(MyInterceptor, :delivering_email, [mail]) do
        assert_called_with(MySecondInterceptor, :delivering_email, [mail]) do
          mail.deliver_now
        end
      end

      ActionMailer::Base.unregister_interceptors("MailRegisterTest::MyInterceptor", MySecondInterceptor)
      assert_not_called(MyInterceptor, :delivering_email, returns: mail) do
        mail.deliver_now
      end
      assert_not_called(MySecondInterceptor, :delivering_email, returns: mail) do
        mail.deliver_now
      end
    end
  end

  test "you can register an interceptor for only a specific mailer" do
    mail_side_effects do
      inherited_mailer = Class.new(BaseMailer) do
        def welcome
          mail
        end
      end

      inherited_mailer.register_interceptor(MyInterceptor)
      mail = inherited_mailer.welcome
      assert_called_with(MyInterceptor, :delivering_email, [mail]) do
        mail.deliver_now
      end

      mail = BaseMailer.welcome
      assert_not_called(MyInterceptor, :delivering_email, returns: mail) do
        mail.deliver_now
      end
    end
  end

  test "you can register an interceptor and it will only apply for inherited mailers" do
    mail_side_effects do
      inherited_mailer = Class.new(BaseMailer)
      inherited_child_mailer = Class.new(inherited_mailer) do
        def welcome
          mail
        end
      end

      inherited_mailer.register_interceptor(MyInterceptor)
      mail = inherited_child_mailer.welcome
      assert_called_with(MyInterceptor, :delivering_email, [mail]) do
        mail.deliver_now
      end

      mail = BaseMailer.welcome
      assert_not_called(MyInterceptor, :delivering_email, [mail]) do
        mail.deliver_now
      end
    end
  end

  test "you can unregister an interceptor only via the registered class" do
    mail_side_effects do
      BaseMailer.register_interceptor(MyInterceptor)
      mail = BaseMailer.welcome
      assert_called_with(MyInterceptor, :delivering_email, [mail]) do
        mail.deliver_now
      end

      ActionMailer::Base.unregister_interceptor(MyInterceptor)
      assert_called_with(MyInterceptor, :delivering_email, [mail]) do
        mail.deliver_now
      end

      BaseMailer.unregister_interceptor(MyInterceptor)
      assert_not_called(MyInterceptor, :delivering_email, returns: mail) do
        mail.deliver_now
      end
    end
  end

  private
    def mail_side_effects
      # old_observers = ActionMailer::MailRegister::BaseRegister.mailers_observers
      # old_delivery_interceptors = ActionMailer::MailRegister::BaseRegister.mailers_interceptors
      old_observers = Mail.class_variable_get(:@@delivery_notification_observers)
      old_delivery_interceptors = Mail.class_variable_get(:@@delivery_interceptors)
      yield
    ensure
      # ActionMailer::MailRegister::BaseRegister.mailers_observers = old_observers
      # ActionMailer::MailRegister::BaseRegister.mailers_observers = old_delivery_interceptors
      Mail.class_variable_set(:@@delivery_notification_observers, old_observers)
      Mail.class_variable_set(:@@delivery_interceptors, old_delivery_interceptors)
    end
end

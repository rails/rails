# frozen_string_literal: true

require "abstract_unit"
require "action_view"
require "action_controller"

class I18nTestMailer < ActionMailer::Base
  configure do |c|
    c.assets_dir = ""
  end

  def mail_with_i18n_subject(recipient)
    @recipient  = recipient
    I18n.locale = :de
    mail(to: recipient, subject: I18n.t(:email_subject),
      from: "system@loudthinking.com", date: Time.local(2004, 12, 12))
  end
end

class TestController < ActionController::Base
  def send_mail
    email = I18nTestMailer.mail_with_i18n_subject("test@localhost").deliver_now
    render plain: "Mail sent - Subject: #{email.subject}"
  end
end

class ActionMailerI18nWithControllerTest < ActionDispatch::IntegrationTest
  Routes = ActionDispatch::Routing::RouteSet.new
  Routes.draw do
    ActiveSupport::Deprecation.silence do
      get ":controller(/:action(/:id))"
    end
  end

  class RoutedRackApp
    attr_reader :routes

    def initialize(routes, &blk)
      @routes = routes
      @stack = ActionDispatch::MiddlewareStack.new(&blk).build(@routes)
    end

    def call(env)
      @stack.call(env)
    end
  end

  APP = RoutedRackApp.new(Routes)

  def app
    APP
  end

  teardown do
    I18n.locale = I18n.default_locale
  end

  def test_send_mail
    stub_any_instance(Mail::SMTP, instance: Mail::SMTP.new({})) do |instance|
      assert_called(instance, :deliver!) do
        with_translation "de", email_subject: "[Anmeldung] Willkommen" do
          get "/test/send_mail"
          assert_equal "Mail sent - Subject: [Anmeldung] Willkommen", @response.body
        end
      end
    end
  end

  private

    def with_translation(locale, data)
      I18n.backend.store_translations(locale, data)
      yield
    ensure
      I18n.backend.reload!
    end
end

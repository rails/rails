require 'abstract_unit'
require 'action_controller'

class I18nTestMailer < ActionMailer::Base
  configure do |c|
    c.assets_dir = ''
  end

  def mail_with_i18n_subject(recipient)
    @recipient  = recipient
    I18n.locale = :de
    mail(to: recipient, subject: "#{I18n.t :email_subject} #{recipient}",
      from: "system@loudthinking.com", date: Time.local(2004, 12, 12))
  end
end

class TestController < ActionController::Base
  def send_mail
    I18nTestMailer.mail_with_i18n_subject("test@localhost").deliver
    render text: 'Mail sent'
  end
end

class ActionMailerI18nWithControllerTest < ActionDispatch::IntegrationTest
  Routes = ActionDispatch::Routing::RouteSet.new
  Routes.draw do
    get ':controller(/:action(/:id))'
  end

  def app
    Routes
  end

  def setup
    I18n.backend.store_translations('de', email_subject: '[Signed up] Welcome')
  end

  def teardown
    I18n.locale = :en
  end

  def test_send_mail
    get '/test/send_mail'
    assert_equal "Mail sent", @response.body
  end
end

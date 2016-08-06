require "abstract_unit"
require "action_controller"

class WelcomeController < ActionController::Base
end

AppRoutes = ActionDispatch::Routing::RouteSet.new

class ActionMailer::Base
  include AppRoutes.url_helpers
end

class UrlTestMailer < ActionMailer::Base
  default_url_options[:host] = "www.basecamphq.com"

  configure do |c|
    c.assets_dir = "" # To get the tests to pass
  end

  def signed_up_with_url(recipient)
    @recipient   = recipient
    @welcome_url = url_for host: "example.com", controller: "welcome", action: "greeting"
    mail(to: recipient, subject: "[Signed up] Welcome #{recipient}",
      from: "system@loudthinking.com", date: Time.local(2004, 12, 12))
  end

  def exercise_url_for(options)
    @options = options
    @url = url_for(@options)
    mail(from: "from@example.com", to: "to@example.com", subject: "subject")
  end
end

class ActionMailerUrlTest < ActionMailer::TestCase
  class DummyModel
    def self.model_name
      OpenStruct.new(route_key: "dummy_model")
    end

    def persisted?
      false
    end

    def model_name
      self.class.model_name
    end

    def to_model
      self
    end
  end

  def encode( text, charset="UTF-8" )
    quoted_printable( text, charset )
  end

  def new_mail( charset="UTF-8" )
    mail = Mail.new
    mail.mime_version = "1.0"
    if charset
      mail.content_type ["text", "plain", { "charset" => charset }]
    end
    mail
  end

  def assert_url_for(expected, options, relative = false)
    expected = "http://www.basecamphq.com#{expected}" if expected.start_with?("/") && !relative
    urls = UrlTestMailer.exercise_url_for(options).body.to_s.chomp.split

    assert_equal expected, urls.first
    assert_equal expected, urls.second
  end

  def setup
    @recipient = "test@localhost"
  end

  def test_url_for
    UrlTestMailer.delivery_method = :test

    AppRoutes.draw do
      ActiveSupport::Deprecation.silence do
        get ":controller(/:action(/:id))"
        get "/welcome"  => "foo#bar", as: "welcome"
        get "/dummy_model" => "foo#baz", as: "dummy_model"
      end
    end

    # string
    assert_url_for "http://foo/", "http://foo/"

    # symbol
    assert_url_for "/welcome", :welcome

    # hash
    assert_url_for "/a/b/c", controller: "a", action: "b", id: "c"
    assert_url_for "/a/b/c", {controller: "a", action: "b", id: "c", only_path: true}, true

    # model
    assert_url_for "/dummy_model", DummyModel.new

    # class
    assert_url_for "/dummy_model", DummyModel

    # array
    assert_url_for "/dummy_model" , [DummyModel]
  end

  def test_signed_up_with_url
    UrlTestMailer.delivery_method = :test

    AppRoutes.draw do
      ActiveSupport::Deprecation.silence do
        get ":controller(/:action(/:id))"
        get "/welcome" => "foo#bar", as: "welcome"
      end
    end

    expected = new_mail
    expected.to      = @recipient
    expected.subject = "[Signed up] Welcome #{@recipient}"
    expected.body    = "Hello there,\n\nMr. #{@recipient}. Please see our greeting at http://example.com/welcome/greeting http://www.basecamphq.com/welcome\n\n<img alt=\"Somelogo\" src=\"/images/somelogo.png\" />"
    expected.from    = "system@loudthinking.com"
    expected.date    = Time.local(2004, 12, 12)
    expected.content_type = "text/html"

    created = nil
    assert_nothing_raised { created = UrlTestMailer.signed_up_with_url(@recipient) }
    assert_not_nil created

    expected.message_id = "<123@456>"
    created.message_id = "<123@456>"
    assert_dom_equal expected.encoded, created.encoded

    assert_nothing_raised { UrlTestMailer.signed_up_with_url(@recipient).deliver_now }
    assert_not_nil ActionMailer::Base.deliveries.first
    delivered = ActionMailer::Base.deliveries.first

    delivered.message_id = "<123@456>"
    assert_dom_equal expected.encoded, delivered.encoded
  end
end

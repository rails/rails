require 'abstract_unit'

class AssetHostMailer < ActionMailer::Base
  def email_with_asset(recipient)
    recipients recipient
    subject    "testing email containing asset path while asset_host is set"
    from       "tester@example.com"
  end
end

class AssetHostTest < Test::Unit::TestCase
  def setup
    set_delivery_method :test
    ActionMailer::Base.perform_deliveries = true
    ActionMailer::Base.deliveries = []

    @recipient = 'test@localhost'
  end

  def teardown
    restore_delivery_method
  end

  def test_asset_host_as_string
    ActionController::Base.asset_host = "http://www.example.com"
    mail = AssetHostMailer.deliver_email_with_asset(@recipient)
    assert_equal "<img alt=\"Somelogo\" src=\"http://www.example.com/images/somelogo.png\" />", mail.body.strip
  end

  def test_asset_host_as_one_arguement_proc
    ActionController::Base.asset_host = Proc.new { |source|
      if source.starts_with?('/images')
        "http://images.example.com"
      else
        "http://assets.example.com"
      end
    }
    mail = AssetHostMailer.deliver_email_with_asset(@recipient)
    assert_equal "<img alt=\"Somelogo\" src=\"http://images.example.com/images/somelogo.png\" />", mail.body.strip
  end

  def test_asset_host_as_two_arguement_proc
    ActionController::Base.asset_host = Proc.new {|source,request|
      if request && request.ssl?
        "https://www.example.com"
      else
        "http://www.example.com"
      end
    }
    mail = nil
    assert_nothing_raised { mail = AssetHostMailer.deliver_email_with_asset(@recipient) }
    assert_equal "<img alt=\"Somelogo\" src=\"http://www.example.com/images/somelogo.png\" />", mail.body.strip
  end
end
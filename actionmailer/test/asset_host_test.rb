require 'abstract_unit'
require 'action_controller'

class AssetHostMailer < ActionMailer::Base
  def email_with_asset
    mail to: 'test@localhost',
      subject: 'testing email containing asset path while asset_host is set',
      from: 'tester@example.com'
  end
end

class AssetHostTest < ActiveSupport::TestCase
  def setup
    set_delivery_method :test
    ActionMailer::Base.perform_deliveries = true
    ActionMailer::Base.deliveries.clear
    AssetHostMailer.configure do |c|
      c.asset_host = 'http://www.example.com'
    end
  end

  def teardown
    restore_delivery_method
  end

  def test_asset_host_as_string
    mail = AssetHostMailer.email_with_asset
    assert_equal '<img alt="Somelogo" src="http://www.example.com/images/somelogo.png" />', mail.body.to_s.strip
  end

  def test_asset_host_as_one_argument_proc
    AssetHostMailer.config.asset_host = Proc.new {
      'http://images.example.com'
    }
    mail = AssetHostMailer.email_with_asset
    assert_equal '<img alt="Somelogo" src="http://images.example.com/images/somelogo.png" />', mail.body.to_s.strip
  end

  def test_asset_host_as_two_argument_proc
    mail = nil
    assert_nothing_raised { mail = AssetHostMailer.email_with_asset }
    assert_equal '<img alt="Somelogo" src="http://www.example.com/images/somelogo.png" />', mail.body.to_s.strip
  end
end

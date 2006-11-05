require File.dirname(__FILE__) + '/abstract_unit'

class TestHelperMailer < ActionMailer::Base
  def test
    recipients "test@example.com"
    from       "tester@example.com"
    body       render(:inline => "Hello, <%= @world %>", :body => { :world => "Earth" })
  end
end

class TestHelperTest < Test::Unit::TestCase
  def setup
    ActionMailer::Base.delivery_method = :test
    ActionMailer::Base.perform_deliveries = true
    ActionMailer::Base.deliveries = []
  end
  
  def test_assert_emails
    assert_nothing_raised do
      assert_emails 1 do
        TestHelperMailer.deliver_test
      end
    end
  end
  
  def test_repeated_assert_emails_calls
    assert_nothing_raised do
      assert_emails 1 do
        TestHelperMailer.deliver_test
      end
    end
    
    assert_nothing_raised do
      assert_emails 2 do
        TestHelperMailer.deliver_test
        TestHelperMailer.deliver_test
      end
    end
  end
  
  def test_assert_no_emails
    assert_nothing_raised do
      assert_no_emails do
        TestHelperMailer.create_test
      end
    end
  end
  
  def test_assert_emails_too_few_sent
    error = assert_raises Test::Unit::AssertionFailedError do
      assert_emails 2 do
        TestHelperMailer.deliver_test
      end
    end
    
    assert_match /2 .* but 1/, error.message
  end
  
  def test_assert_emails_too_many_sent
    error = assert_raises Test::Unit::AssertionFailedError do
      assert_emails 1 do
        TestHelperMailer.deliver_test
        TestHelperMailer.deliver_test
      end
    end
    
    assert_match /1 .* but 2/, error.message
  end
  
  def test_assert_no_emails_failure
    error = assert_raises Test::Unit::AssertionFailedError do
      assert_no_emails do
        TestHelperMailer.deliver_test
      end
    end
    
    assert_match /0 .* but 1/, error.message
  end
end

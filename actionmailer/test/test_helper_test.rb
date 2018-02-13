# frozen_string_literal: true

require "abstract_unit"
require "active_support/testing/stream"

class TestHelperMailer < ActionMailer::Base
  def test
    @world = "Earth"
    mail body: render(inline: "Hello, <%= @world %>"),
      to: "test@example.com",
      from: "tester@example.com"
  end

  def test_args(recipient, name)
    mail body: render(inline: "Hello, #{name}"),
      to: recipient,
      from: "tester@example.com"
  end

  def test_parameter_args
    mail body: render(inline: "All is #{params[:all]}"),
      to: "test@example.com",
      from: "tester@example.com"
  end
end

class TestHelperMailerTest < ActionMailer::TestCase
  include ActiveSupport::Testing::Stream

  def test_setup_sets_right_action_mailer_options
    assert_equal :test, ActionMailer::Base.delivery_method
    assert ActionMailer::Base.perform_deliveries
    assert_equal [], ActionMailer::Base.deliveries
  end

  def test_setup_creates_the_expected_mailer
    assert_kind_of Mail::Message, @expected
    assert_equal "1.0", @expected.mime_version
    assert_equal "text/plain", @expected.mime_type
  end

  def test_mailer_class_is_correctly_inferred
    assert_equal TestHelperMailer, self.class.mailer_class
  end

  def test_determine_default_mailer_raises_correct_error
    assert_raise(ActionMailer::NonInferrableMailerError) do
      self.class.determine_default_mailer("NotAMailerTest")
    end
  end

  def test_charset_is_utf_8
    assert_equal "UTF-8", charset
  end

  def test_encode
    assert_equal "This is あ string", Mail::Encodings.q_value_decode(encode("This is あ string"))
  end

  def test_read_fixture
    assert_equal ["Welcome!"], read_fixture("welcome")
  end

  def test_assert_emails
    assert_nothing_raised do
      assert_emails 1 do
        TestHelperMailer.test.deliver_now
      end
    end
  end

  def test_repeated_assert_emails_calls
    assert_nothing_raised do
      assert_emails 1 do
        TestHelperMailer.test.deliver_now
      end
    end

    assert_nothing_raised do
      assert_emails 2 do
        TestHelperMailer.test.deliver_now
        TestHelperMailer.test.deliver_now
      end
    end
  end

  def test_assert_emails_with_no_block
    assert_nothing_raised do
      TestHelperMailer.test.deliver_now
      assert_emails 1
    end

    assert_nothing_raised do
      TestHelperMailer.test.deliver_now
      TestHelperMailer.test.deliver_now
      assert_emails 3
    end
  end

  def test_assert_no_emails
    assert_nothing_raised do
      assert_no_emails do
        TestHelperMailer.test
      end
    end
  end

  def test_assert_emails_too_few_sent
    error = assert_raise ActiveSupport::TestCase::Assertion do
      assert_emails 2 do
        TestHelperMailer.test.deliver_now
      end
    end

    assert_match(/2 .* but 1/, error.message)
  end

  def test_assert_emails_too_many_sent
    error = assert_raise ActiveSupport::TestCase::Assertion do
      assert_emails 1 do
        TestHelperMailer.test.deliver_now
        TestHelperMailer.test.deliver_now
      end
    end

    assert_match(/1 .* but 2/, error.message)
  end

  def test_assert_emails_message
    TestHelperMailer.test.deliver_now
    error = assert_raise ActiveSupport::TestCase::Assertion do
      assert_emails 2 do
        TestHelperMailer.test.deliver_now
      end
    end
    assert_match "Expected: 2", error.message
    assert_match "Actual: 1", error.message
  end

  def test_assert_no_emails_failure
    error = assert_raise ActiveSupport::TestCase::Assertion do
      assert_no_emails do
        TestHelperMailer.test.deliver_now
      end
    end

    assert_match(/0 .* but 1/, error.message)
  end

  def test_assert_enqueued_emails
    assert_nothing_raised do
      assert_enqueued_emails 1 do
        silence_stream($stdout) do
          TestHelperMailer.test.deliver_later
        end
      end
    end
  end

  def test_assert_enqueued_parameterized_emails
    assert_nothing_raised do
      assert_enqueued_emails 1 do
        silence_stream($stdout) do
          TestHelperMailer.with(a: 1).test.deliver_later
        end
      end
    end
  end

  def test_assert_enqueued_emails_too_few_sent
    error = assert_raise ActiveSupport::TestCase::Assertion do
      assert_enqueued_emails 2 do
        silence_stream($stdout) do
          TestHelperMailer.test.deliver_later
        end
      end
    end

    assert_match(/2 .* but 1/, error.message)
  end

  def test_assert_enqueued_emails_too_many_sent
    error = assert_raise ActiveSupport::TestCase::Assertion do
      assert_enqueued_emails 1 do
        silence_stream($stdout) do
          TestHelperMailer.test.deliver_later
          TestHelperMailer.test.deliver_later
        end
      end
    end

    assert_match(/1 .* but 2/, error.message)
  end

  def test_assert_no_enqueued_emails
    assert_nothing_raised do
      assert_no_enqueued_emails do
        TestHelperMailer.test.deliver_now
      end
    end
  end

  def test_assert_no_enqueued_parameterized_emails
    assert_nothing_raised do
      assert_no_enqueued_emails do
        TestHelperMailer.with(a: 1).test.deliver_now
      end
    end
  end

  def test_assert_no_enqueued_emails_failure
    error = assert_raise ActiveSupport::TestCase::Assertion do
      assert_no_enqueued_emails do
        silence_stream($stdout) do
          TestHelperMailer.test.deliver_later
        end
      end
    end

    assert_match(/0 .* but 1/, error.message)
  end

  def test_assert_enqueued_email_with
    assert_nothing_raised do
      assert_enqueued_email_with TestHelperMailer, :test do
        silence_stream($stdout) do
          TestHelperMailer.test.deliver_later
        end
      end
    end
  end

  def test_assert_enqueued_email_with_args
    assert_nothing_raised do
      assert_enqueued_email_with TestHelperMailer, :test_args, args: ["some_email", "some_name"] do
        silence_stream($stdout) do
          TestHelperMailer.test_args("some_email", "some_name").deliver_later
        end
      end
    end
  end

  def test_assert_enqueued_email_with_parameterized_args
    assert_nothing_raised do
      assert_enqueued_email_with TestHelperMailer, :test_parameter_args, args: { all: "good" } do
        silence_stream($stdout) do
          TestHelperMailer.with(all: "good").test_parameter_args.deliver_later
        end
      end
    end
  end
end

class AnotherTestHelperMailerTest < ActionMailer::TestCase
  tests TestHelperMailer

  def setup
    @test_var = "a value"
  end

  def test_setup_shouldnt_conflict_with_mailer_setup
    assert_kind_of Mail::Message, @expected
    assert_equal "a value", @test_var
  end
end

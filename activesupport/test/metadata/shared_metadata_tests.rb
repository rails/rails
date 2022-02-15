# frozen_string_literal: true

module SharedMessageMetadataTests
  def null_serializing?
    false
  end

  def test_encryption_and_decryption_with_same_purpose
    assert_equal data, parse(generate(data, purpose: "checkout"), purpose: "checkout")
    assert_equal data, parse(generate(data))

    string_message = "address: #23, main street"
    assert_equal string_message, parse(generate(string_message, purpose: "shipping"), purpose: "shipping")
  end

  def test_verifies_array_when_purpose_matches
    skip if null_serializing?

    data = [ "credit_card_no: 5012-6748-9087-5678", { "card_holder" => "Donald", "issued_on" => Time.local(2017) }, 12345 ]
    assert_equal data, parse(generate(data, purpose: :registration), purpose: :registration)
  end

  def test_encryption_and_decryption_with_different_purposes_returns_nil
    assert_nil parse(generate(data, purpose: "payment"), purpose: "sign up")
    assert_nil parse(generate(data, purpose: "payment"))
    assert_nil parse(generate(data), purpose: "sign up")
  end

  def test_purpose_using_symbols
    assert_equal data, parse(generate(data, purpose: :checkout), purpose: :checkout)
    assert_equal data, parse(generate(data, purpose: :checkout), purpose: "checkout")
    assert_equal data, parse(generate(data, purpose: "checkout"), purpose: :checkout)
  end

  def test_passing_expires_at_sets_expiration_date
    encrypted_message = generate(data, expires_at: 1.hour.from_now)

    travel 59.minutes
    assert_equal data, parse(encrypted_message)

    travel 2.minutes
    assert_nil parse(encrypted_message)
  end

  def test_set_relative_expiration_date_by_passing_expires_in
    encrypted_message = generate(data, expires_in: 2.hours)

    travel 1.hour
    assert_equal data, parse(encrypted_message)

    travel 1.hour + 1.second
    assert_nil parse(encrypted_message)
  end

  def test_passing_expires_in_less_than_a_second_is_not_expired
    freeze_time do
      encrypted_message = generate(data, expires_in: 1.second)

      travel 0.5.seconds
      assert_equal data, parse(encrypted_message)

      travel 1.second
      assert_nil parse(encrypted_message)
    end
  end

  def test_favor_expires_at_over_expires_in
    payment_related_message = generate(data, purpose: "payment", expires_at: 2.year.from_now, expires_in: 1.second)

    travel 1.year
    assert_equal data, parse(payment_related_message, purpose: :payment)

    travel 1.year + 1.day
    assert_nil parse(payment_related_message, purpose: "payment")
  end

  def test_skip_expires_at_and_expires_in_to_disable_expiration_check
    payment_related_message = generate(data, purpose: "payment")

    travel 100.years
    assert_equal data, parse(payment_related_message, purpose: "payment")
  end

  private
    def data
      { "credit_card_no" => "5012-6784-9087-5678", "card_holder" => { "name" => "Donald" } }
    end
end

require 'abstract_unit'
require 'active_support/time'

class ClaimsTest < ActiveSupport::TestCase
  def setup
    @payload = 'payload'
    @claims = ActiveSupport::Claims.new(payload: @payload, for: 'test', expires_at: Time.utc(2022))
  end

  def test_to_hash
    hash = { pld: 'payload', for: 'test', exp: '2022-01-01T00:00:00.000Z' }
    assert_equal hash, @claims.to_h
  end

  def test_verify_returns_value_with_valid_claims
    assert_equal @payload, ActiveSupport::Claims.verify!(@claims.to_h, for: 'test')
  end

  def test_verify_returns_value_with_default_claims
    claims = ActiveSupport::Claims.new(payload: @payload)
    assert_equal @payload, ActiveSupport::Claims.verify!(claims.to_h)
  end
end

class ClaimsPurposeTest < ActiveSupport::TestCase
  def setup
    @payload = 'payload'
    @claims = ActiveSupport::Claims.new(payload: @payload, for: 'test')
  end

  def test_default_purpose_without_for
    assert_equal 'universal', ActiveSupport::Claims.new(payload: @payload).purpose
  end

  def test_verify_exception_on_invalid_purpose
    assert_raise(ActiveSupport::Claims::InvalidClaims) do
      ActiveSupport::Claims.verify!(@claims.to_h, for: 'different_purpose')
    end
  end

  def test_equal_only_with_same_purpose
    assert_equal @claims, ActiveSupport::Claims.new(payload: @payload, for: 'test')
    assert_not_equal @claims, ActiveSupport::Claims.new(payload: @payload, for: 'login')
    assert_not_equal @claims, ActiveSupport::Claims.new(payload: @payload)
  end
end

class ClaimsExpirationTest < ActiveSupport::TestCase
  def setup
    @payload = 'payload'
  end

  test 'expires_in defaults to class level expiration' do
    with_expiration_in 1.hour do
      encoded_claims = encode_claims.to_h

      travel 59.minutes
      assert_equal @payload, ActiveSupport::Claims.verify!(encoded_claims)

      travel 5.minutes
      assert_expired encoded_claims
    end
  end

  test 'passing in expires_in overrides class level expiration' do
    with_expiration_in 1.hour do
      encoded_claims = encode_claims expires_in: 2.hours

      travel 1.hour
      assert_equal @payload, ActiveSupport::Claims.verify!(encoded_claims)

      travel 1.1.hours
      assert_expired encoded_claims
    end
  end

  test 'passing expires_in less than a second is not expired' do
    encoded_claims = encode_claims expires_in: 1.second

    travel 0.5.second
    assert_equal @payload, ActiveSupport::Claims.verify!(encoded_claims)

    travel 2.seconds
    assert_expired encoded_claims
  end

  test 'passing expires_in nil turns off expiration checking' do
    with_expiration_in 1.hour do
      encoded_claims = encode_claims expires_in: nil

      travel 1.hour
      assert_equal @payload, ActiveSupport::Claims.verify!(encoded_claims)

      travel 1.hour
      assert_equal @payload, ActiveSupport::Claims.verify!(encoded_claims)
    end
  end

  test 'passing expires_at sets expiration date' do
    date = Date.today.end_of_day
    claims = ActiveSupport::Claims.new(payload: @payload, expires_at: date)

    assert_equal date, claims.expires_at

    travel 1.day
    assert_expired claims.to_h
  end

  test 'passing expires_at nil turns off expiration checking' do
    with_expiration_in 1.hour do
      encoded_claims = encode_claims expires_at: nil

      travel 4.hours
      assert_equal @payload, ActiveSupport::Claims.verify!(encoded_claims)
    end
  end

  test 'passing expires_at overrides class level expires_in' do
    with_expiration_in 1.hour do
      date = Date.tomorrow.end_of_day
      claims = ActiveSupport::Claims.new(payload: @payload, expires_at: date)

      assert_equal date, claims.expires_at

      travel 2.hours
      assert_equal @payload, ActiveSupport::Claims.verify!(claims.to_h)
    end
  end

  test 'favor expires_at over expires_in' do
    claims = encode_claims expires_at: Date.tomorrow.end_of_day, expires_in: 1.hour

    travel 1.hour
    assert ActiveSupport::Claims.verify!(claims)
  end

  private
    def with_expiration_in(expires_in)
      old_expires, ActiveSupport::Claims.expires_in = ActiveSupport::Claims.expires_in, expires_in
      yield
    ensure
      ActiveSupport::Claims.expires_in = old_expires
    end

    def assert_expired(claims, options = {})
      assert_raises ActiveSupport::Claims::ExpiredClaims do
        ActiveSupport::Claims.verify! claims, options
      end
    end

    def encode_claims(options = {})
      ActiveSupport::Claims.new(payload: @payload, **options).to_h
    end
end

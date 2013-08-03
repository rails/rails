require 'abstract_unit'
require 'active_support/log_subscriber/test_helper'

class AuthenticityTokenTest < ActiveSupport::TestCase
  test 'should generate a master token that is random' do
    first_session = {}
    ActionController::AuthenticityToken.generate_masked(first_session)

    second_session = {}
    ActionController::AuthenticityToken.generate_masked(second_session)

    refute_equal first_session[:_csrf_token], second_session[:_csrf_token]
  end

  test 'should generate a master token that is a 32-byte base64 string' do
    session = {}
    ActionController::AuthenticityToken.generate_masked(session)
    bytes = Base64.strict_decode64(session[:_csrf_token])
    assert_equal 32, bytes.length
  end

  test 'should generate masked tokens that are 64-byte base64 strings' do
    masked_token = ActionController::AuthenticityToken.generate_masked({})
    bytes = Base64.strict_decode64(masked_token)
    assert_equal 64, bytes.length
  end

  test 'should save a new master token to the session if none is present' do
    session = {}
    ActionController::AuthenticityToken.generate_masked(session)
    refute_nil session[:_csrf_token]
  end

  test 'should not overwrite an existing master token' do
    existing = SecureRandom.base64(32)
    session = {:_csrf_token => existing}
    ActionController::AuthenticityToken.generate_masked(session)
    assert_equal existing, session[:_csrf_token]
  end

  test 'should generate masked tokens that are different each time' do
    session = {}
    first = ActionController::AuthenticityToken.generate_masked(session)
    second = ActionController::AuthenticityToken.generate_masked(session)
    refute_equal first, second
  end

  test 'should be able to verify a masked token' do
    session = {}
    masked_token = ActionController::AuthenticityToken.generate_masked(session)
    assert ActionController::AuthenticityToken.valid?(session, masked_token)
  end

  test 'should be able to verify an unmasked (master) token' do
    # Generate a master token
    session = {}
    ActionController::AuthenticityToken.generate_masked(session)
    assert ActionController::AuthenticityToken.valid?(session, session[:_csrf_token])
  end

  test 'should warn when verifying an unmasked token' do
    logger = ActiveSupport::LogSubscriber::TestHelper::MockLogger.new

    session = {}
    ActionController::AuthenticityToken.generate_masked(session)
    ActionController::AuthenticityToken.valid?(session, session[:_csrf_token], logger)

    assert_equal 1, logger.logged(:warn).size
    assert_match(/unmasked CSRF token/, logger.logged(:warn).last)
  end

  test 'should reject an invalid unmasked token' do
    session = {}
    ActionController::AuthenticityToken.generate_masked(session)
    refute ActionController::AuthenticityToken.valid?(session, SecureRandom.base64(32))
  end

  test 'should reject an invalid masked token' do
    session = {}
    ActionController::AuthenticityToken.generate_masked(session)
    refute ActionController::AuthenticityToken.valid?(session, SecureRandom.base64(64))
  end

  test 'should reject a token from a different session' do
    old_session = {}
    old_masked_token = ActionController::AuthenticityToken.generate_masked(old_session)

    new_session = {}
    refute ActionController::AuthenticityToken.valid?(new_session, old_masked_token)
  end

  test 'should reject a nil token' do
    refute ActionController::AuthenticityToken.valid?({}, nil)
  end

  test 'should reject an empty token' do
    refute ActionController::AuthenticityToken.valid?({}, '')
  end

  test 'should reject a malformed token' do
    refute ActionController::AuthenticityToken.valid?({}, SecureRandom.base64(42))
  end
end

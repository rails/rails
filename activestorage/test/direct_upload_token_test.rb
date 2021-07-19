# frozen_string_literal: true

require "test_helper"

class DirectUploadTokenTest < ActionController::TestCase
  setup do
    @session = {}
    @service_name = "local"
    @avatar_attachment_name = "User#avatar"
  end

  def test_validates_correct_token
    token = ActiveStorage::DirectUploadToken.generate_direct_upload_token(@avatar_attachment_name, @service_name, @session)
    verified_service_name = ActiveStorage::DirectUploadToken.verify_direct_upload_token(token, @avatar_attachment_name, @session)
    assert_equal verified_service_name, @service_name
  end

  def test_not_validates_token_when_session_is_empty
    token = ActiveStorage::DirectUploadToken.generate_direct_upload_token(@avatar_attachment_name, @service_name, {})

    assert_raises(ActiveStorage::WrongDirectUploadTokenError) do
      ActiveStorage::DirectUploadToken.verify_direct_upload_token(token, @avatar_attachment_name, @session)
    end
  end

  def test_not_validates_token_from_different_attachment
    background_attachment_name = "User#background"
    token = ActiveStorage::DirectUploadToken.generate_direct_upload_token(background_attachment_name, @service_name, @session)

    assert_raises(ActiveStorage::WrongDirectUploadTokenError) do
      ActiveStorage::DirectUploadToken.verify_direct_upload_token(token, @avatar_attachment_name, @session)
    end
  end

  def test_not_validates_token_from_different_session
    token = ActiveStorage::DirectUploadToken.generate_direct_upload_token(@avatar_attachment_name, @service_name, @session)

    another_session = {}
    ActiveStorage::DirectUploadToken.generate_direct_upload_token(@avatar_attachment_name, @service_name, another_session)

    assert_raises(ActiveStorage::WrongDirectUploadTokenError) do
      ActiveStorage::DirectUploadToken.verify_direct_upload_token(token, @avatar_attachment_name, another_session)
    end
  end
end

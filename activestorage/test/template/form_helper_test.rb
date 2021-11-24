# frozen_string_literal: true

require "test_helper"
require "database/setup"
require "minitest/mock"

class ActiveStorage::FormHelperTest < ActionView::TestCase
  tests(ActionView::Helpers::FormHelper)

  test "form_with model" do
    assert_dom_equal(
      <<~HTML.squish.gsub("> ", ">"),
        <form enctype="multipart/form-data" action="/" accept-charset="UTF-8" method="post">
          <input data-direct-upload-url="http://test.host/rails/active_storage/direct_uploads"
                data-direct-upload-attachment-name="user#avatar"
                data-direct-upload-token="token"
                type="file"
                name="user[avatar]"
                id="user_avatar" />
        </form>
      HTML
      ActiveStorage::DirectUploadToken.stub(:generate_direct_upload_token, "token") do
        form_with(model: User.new, url: "/") do |f|
          f.file_field(:avatar, direct_upload: true)
        end
      end
    )
  end

  test "form_with scope" do
    assert_dom_equal(
      <<~HTML.squish.gsub("> ", ">"),
        <form enctype="multipart/form-data" action="/" accept-charset="UTF-8" method="post">
          <input data-direct-upload-url="http://test.host/rails/active_storage/direct_uploads"
                data-direct-upload-attachment-name="user#avatar"
                data-direct-upload-token="token"
                type="file"
                name="user[avatar]"
                id="user_avatar" />
        </form>
      HTML
      ActiveStorage::DirectUploadToken.stub(:generate_direct_upload_token, "token") do
        form_with(scope: :user, url: "/") do |f|
          f.file_field(:avatar, direct_upload: { model: "User", attachment: "avatar" })
        end
      end
    )
  end

  test "form_with without attachment specified" do
    error = assert_raises(ArgumentError) do
      form_with(scope: :user, url: "/") do |f|
        f.file_field(:avatar, direct_upload: true)
      end
    end
    assert_equal(<<~MSG.squish, error.message)
      Invalid direct upload options. Please specify a :model and :attachment.
    MSG
  end
end

# frozen_string_literal: true

require "test_helper"
require "database/setup"
require "minitest/mock"

class ActiveStorage::FormTagHelperTest < ActionView::TestCase
  tests(ActionView::Helpers::FormTagHelper)

  test "file_field tag" do
    assert_dom_equal(
      <<~HTML.squish,
        <input type="file"
               name="picsplz"
               id="picsplz"
               class="pix"
               data-direct-upload-url="http://test.host/rails/active_storage/direct_uploads"
               data-direct-upload-attachment-name="user#avatar"
               data-direct-upload-token="token" />
      HTML
      ActiveStorage::DirectUploadToken.stub(:generate_direct_upload_token, "token") do
        file_field_tag("picsplz", class: "pix", direct_upload: { model: "User", attachment: "avatar"  })
      end
    )
  end

  test "file_field_tag without attachment specified" do
    error = assert_raises(ArgumentError) do
      file_field_tag("picsplz", class: "pix", direct_upload: true)
    end
    assert_equal(<<~MSG.squish, error.message)
      Invalid direct upload options. Please specify a :model and :attachment.
    MSG
  end

  def test_file_field_tag_with_direct_upload_doesnt_mutate_arguments
    original_options = { class: "pix", direct_upload: { model: "User", attachment: "avatar"  } }

    assert_dom_equal(
      <<~HTML.squish,
        <input type="file"
               name="picsplz"
               id="picsplz"
               class="pix"
               data-direct-upload-url="http://test.host/rails/active_storage/direct_uploads"
               data-direct-upload-attachment-name="user#avatar"
               data-direct-upload-token="token" />
      HTML
      ActiveStorage::DirectUploadToken.stub(:generate_direct_upload_token, "token") do
        file_field_tag("picsplz", original_options)
      end
    )

    assert_equal({ class: "pix", direct_upload: { model: "User", attachment: "avatar"  } }, original_options)
  end
end

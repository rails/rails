# frozen_string_literal: true

require "test_helper"
require "database/setup"

class ActiveStorage::PublicDiskControllerTest < ActionDispatch::IntegrationTest
  test "showing public blob" do
    with_service("local_public") do
      blob = create_blob(content_type: "image/jpg")

      get blob.url
      assert_response :ok
      assert_equal "image/jpg", response.headers["Content-Type"]
      assert_equal "Hello world!", response.body
    end
  end

  test "showing private blob as a public blob" do
    blob = create_blob(content_type: "image/jpg")

    with_service("local_public") do
      get rails_disk_service_public_url(key: blob.key, filename: "foo.jpg")
      assert_response :unauthorized
    end
  end

  test "showing public blob with invalid key" do
    with_service("local_public") do
      get rails_disk_service_public_url(key: "abc123", filename: "foo.jpg")
      assert_response :not_found
    end
  end
end

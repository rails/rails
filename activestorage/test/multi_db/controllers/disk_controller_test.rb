# frozen_string_literal: true

require "multi_db_test_helper"
require "database/setup"

class ActiveStorage::DiskControllerTest < ActionDispatch::IntegrationTest
  test "showing main blob inline" do
    main_blob = create_main_blob(filename: "hello.jpg", content_type: "image/jpeg")

    get main_blob.url
    assert_response :ok
    assert_equal "inline; filename=\"hello.jpg\"; filename*=UTF-8''hello.jpg", response.headers["Content-Disposition"]
    assert_equal "image/jpeg", response.headers["Content-Type"]
    assert_equal "Hello world!", response.body
  end

  test "showing animals blob inline" do
    animals_blob = create_animals_blob(filename: "hello.jpg", content_type: "image/jpeg")

    get animals_blob.url
    assert_response :ok
    assert_equal "inline; filename=\"hello.jpg\"; filename*=UTF-8''hello.jpg", response.headers["Content-Disposition"]
    assert_equal "image/jpeg", response.headers["Content-Type"]
    assert_equal "Hello world!", response.body
  end

  test "showing main blob as attachment" do
    main_blob = create_main_blob(filename: "hello.txt", content_type: "text/plain")

    get main_blob.url(disposition: :attachment)
    assert_response :ok
    assert_equal "attachment; filename=\"hello.txt\"; filename*=UTF-8''hello.txt", response.headers["Content-Disposition"]
    assert_equal "text/plain", response.headers["Content-Type"]
    assert_equal "Hello world!", response.body
  end

  test "showing animals blob as attachment" do
    animals_blob = create_animals_blob(filename: "hello.txt", content_type: "text/plain")

    get animals_blob.url(disposition: :attachment)
    assert_response :ok
    assert_equal "attachment; filename=\"hello.txt\"; filename*=UTF-8''hello.txt", response.headers["Content-Disposition"]
    assert_equal "text/plain", response.headers["Content-Type"]
    assert_equal "Hello world!", response.body
  end

  test "showing main blob range" do
    main_blob = create_main_blob(filename: "hello.txt", content_type: "text/plain")

    get main_blob.url, headers: { "Range" => "bytes=5-9" }
    assert_response :partial_content
    assert_equal "attachment; filename=\"hello.txt\"; filename*=UTF-8''hello.txt", response.headers["Content-Disposition"]
    assert_equal "text/plain", response.headers["Content-Type"]
    assert_equal " worl", response.body
  end

  test "showing animals blob range" do
    animals_blob = create_animals_blob(filename: "hello.txt", content_type: "text/plain")

    get animals_blob.url, headers: { "Range" => "bytes=5-9" }
    assert_response :partial_content
    assert_equal "attachment; filename=\"hello.txt\"; filename*=UTF-8''hello.txt", response.headers["Content-Disposition"]
    assert_equal "text/plain", response.headers["Content-Type"]
    assert_equal " worl", response.body
  end

  test "showing main blob with invalid range" do
    main_blob = create_main_blob
    get main_blob.url, headers: { "Range" => "bytes=1000-1000" }
    assert_response :range_not_satisfiable
  end

  test "showing animals blob with invalid range" do
    animals_blob = create_animals_blob
    get animals_blob.url, headers: { "Range" => "bytes=1000-1000" }
    assert_response :range_not_satisfiable
  end

  test "showing main blob that does not exist" do
    main_blob = create_main_blob
    main_blob.delete

    get main_blob.url
    assert_response :not_found
  end

  test "showing animals blob that does not exist" do
    animals_blob = create_animals_blob
    animals_blob.delete

    get animals_blob.url
    assert_response :not_found
  end

  test "showing main blob with invalid key" do
    get rails_main_disk_service_url(encoded_key: "Invalid key", filename: "hello.txt")
    assert_response :not_found
  end

  test "showing animals blob with invalid key" do
    get rails_animals_disk_service_url(encoded_key: "Invalid key", filename: "hello.txt")
    assert_response :not_found
  end

  test "showing main public blob" do
    with_main_service("local_public") do
      main_blob = create_main_blob(content_type: "image/jpeg")

      get main_blob.url
      assert_response :ok
      assert_equal "image/jpeg", response.headers["Content-Type"]
      assert_equal "Hello world!", response.body
    end
  end

  test "showing animals public blob" do
    with_animals_service("local_public") do
      animals_blob = create_animals_blob(content_type: "image/jpeg")

      get animals_blob.url
      assert_response :ok
      assert_equal "image/jpeg", response.headers["Content-Type"]
      assert_equal "Hello world!", response.body
    end
  end

  test "showing main public blob variant" do
    with_main_service("local_public") do
      main_blob = create_main_file_blob.variant(resize_to_limit: [100, 100]).processed

      get main_blob.url
      assert_response :ok
      assert_equal "image/jpeg", response.headers["Content-Type"]
    end
  end

  test "showing animals public blob variant" do
    with_animals_service("local_public") do
      animals_blob = create_animals_file_blob.variant(resize_to_limit: [100, 100]).processed

      get animals_blob.url
      assert_response :ok
      assert_equal "image/jpeg", response.headers["Content-Type"]
    end
  end

  test "directly uploading main blob with integrity" do
    data = "Something else entirely!"
    main_blob = create_main_blob_before_direct_upload byte_size: data.size, checksum: ActiveStorage.checksum_implementation.base64digest(data)

    put main_blob.service_url_for_direct_upload, params: data, headers: { "Content-Type" => "text/plain" }
    assert_response :no_content
    assert_equal data, main_blob.download
  end

  test "directly uploading animals blob with integrity" do
    data = "Something else entirely!"
    animals_blob = create_animals_blob_before_direct_upload byte_size: data.size, checksum: ActiveStorage.checksum_implementation.base64digest(data)

    put animals_blob.service_url_for_direct_upload, params: data, headers: { "Content-Type" => "text/plain" }
    assert_response :no_content
    assert_equal data, animals_blob.download
  end

  test "directly uploading main blob without integrity" do
    data = "Something else entirely!"
    main_blob = create_main_blob_before_direct_upload byte_size: data.size, checksum: ActiveStorage.checksum_implementation.base64digest("bad data")

    put main_blob.service_url_for_direct_upload, params: data
    assert_response :unprocessable_entity
    assert_not main_blob.service.exist?(main_blob.key)
  end

  test "directly uploading animals blob without integrity" do
    data = "Something else entirely!"
    animals_blob = create_animals_blob_before_direct_upload byte_size: data.size, checksum: ActiveStorage.checksum_implementation.base64digest("bad data")

    put animals_blob.service_url_for_direct_upload, params: data
    assert_response :unprocessable_entity
    assert_not animals_blob.service.exist?(animals_blob.key)
  end

  test "directly uploading main blob with mismatched content type" do
    data = "Something else entirely!"
    main_blob = create_main_blob_before_direct_upload byte_size: data.size, checksum: ActiveStorage.checksum_implementation.base64digest(data)

    put main_blob.service_url_for_direct_upload, params: data, headers: { "Content-Type" => "application/octet-stream" }
    assert_response :unprocessable_entity
    assert_not main_blob.service.exist?(main_blob.key)
  end

  test "directly uploading blob with mismatched content type" do
    data = "Something else entirely!"
    animals_blob = create_animals_blob_before_direct_upload byte_size: data.size, checksum: ActiveStorage.checksum_implementation.base64digest(data)

    put animals_blob.service_url_for_direct_upload, params: data, headers: { "Content-Type" => "application/octet-stream" }
    assert_response :unprocessable_entity
    assert_not animals_blob.service.exist?(animals_blob.key)
  end

  test "directly uploading main blob with different but equivalent content type" do
    data = "Something else entirely!"
    main_blob = create_main_blob_before_direct_upload(
      byte_size: data.size, checksum: ActiveStorage.checksum_implementation.base64digest(data), content_type: "application/x-gzip")

    put main_blob.service_url_for_direct_upload, params: data, headers: { "Content-Type" => "application/x-gzip" }
    assert_response :no_content
    assert_equal data, main_blob.download
  end

  test "directly uploading blob with different but equivalent content type" do
    data = "Something else entirely!"
    animals_blob = create_animals_blob_before_direct_upload(
      byte_size: data.size, checksum: ActiveStorage.checksum_implementation.base64digest(data), content_type: "application/x-gzip")

    put animals_blob.service_url_for_direct_upload, params: data, headers: { "Content-Type" => "application/x-gzip" }
    assert_response :no_content
    assert_equal data, animals_blob.download
  end

  test "directly uploading main blob with mismatched content length" do
    data = "Something else entirely!"
    main_blob = create_main_blob_before_direct_upload(
      byte_size: data.size - 1, checksum: ActiveStorage.checksum_implementation.base64digest(data), content_type: "text/plain")

    put main_blob.service_url_for_direct_upload, params: data, headers: { "Content-Type" => "text/plain" }
    assert_response :unprocessable_entity
      assert_not main_blob.service.exist?(main_blob.key)
  end

  test "directly uploading animals blob with mismatched content length" do
    data = "Something else entirely!"
    animals_blob = create_animals_blob_before_direct_upload(
      byte_size: data.size - 1, checksum: ActiveStorage.checksum_implementation.base64digest(data), content_type: "text/plain")

    put animals_blob.service_url_for_direct_upload, params: data, headers: { "Content-Type" => "text/plain" }
    assert_response :unprocessable_entity
    assert_not animals_blob.service.exist?(animals_blob.key)
  end

  test "directly uploading main blob with invalid token" do
    put update_rails_main_disk_service_url(encoded_token: "invalid"),
      params: "Something else entirely!", headers: { "Content-Type" => "text/plain" }
    assert_response :not_found
  end

  test "directly uploading animals blob with invalid token" do
    put update_rails_animals_disk_service_url(encoded_token: "invalid"),
      params: "Something else entirely!", headers: { "Content-Type" => "text/plain" }
    assert_response :not_found
  end
end

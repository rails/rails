# frozen_string_literal: true

require 'test_helper'
require 'database/setup'

class ActiveStorage::Blobs::RedirectControllerTest < ActionDispatch::IntegrationTest
  setup do
    @blob = create_file_blob filename: 'racecar.jpg'
  end

  test 'invalid signed ID' do
    get rails_service_blob_url('invalid', 'racecar.jpg')
    assert_response :not_found
  end

  test 'HTTP caching' do
    get rails_storage_redirect_url(@blob)
    assert_redirected_to(/racecar\.jpg/)
    assert_equal 'max-age=300, private', response.headers['Cache-Control']
  end
end

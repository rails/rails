# frozen_string_literal: true

require 'test_helper'
require 'database/setup'

class ActiveStorage::Blobs::ProxyControllerTest < ActionDispatch::IntegrationTest
  test 'invalid signed ID' do
    get rails_service_blob_proxy_url('invalid', 'racecar.jpg')
    assert_response :not_found
  end

  test 'HTTP caching' do
    get rails_storage_proxy_url(create_file_blob(filename: 'racecar.jpg'))
    assert_response :success
    assert_equal 'max-age=3155695200, public', response.headers['Cache-Control']
  end

  test 'forcing Content-Type to binary' do
    get rails_storage_proxy_url(create_blob(content_type: 'text/html'))
    assert_equal 'application/octet-stream', response.headers['Content-Type']
  end

  test 'forcing Content-Disposition to attachment' do
    get rails_storage_proxy_url(create_blob(content_type: 'application/zip'))
    assert_match(/^attachment; /, response.headers['Content-Disposition'])
  end
end

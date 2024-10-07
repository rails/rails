# frozen_string_literal: true

require "test_helper"

class ActiveStorage::Service::UrlConfigTest < ActiveSupport::TestCase
  def test_fetch_url
    uri = URI.parse("disk://tmp/storage")
    config = ActiveStorage::Service::UrlConfig.new(uri)
    assert_equal "disk", config.fetch(:service)

    uri = URI.parse("disk://tmp/storage?default=false")
    config = ActiveStorage::Service::UrlConfig.new(uri)
    assert_equal "false", config.fetch(:params)[:default]

    uri = URI.parse("disk://tmp/storage?cache_control=public,max-age=31536000&read_only=true")
    config = ActiveStorage::Service::UrlConfig.new(uri)
    assert_equal "public,max-age=31536000", config.params[:cache_control]
    assert_equal "true", config.params[:read_only]
  end
end

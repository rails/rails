# frozen_string_literal: true

require "test_helper"
require "database/setup"

class ActiveStorage::UrlOptionsTest < ActionView::TestCase
  tests ActionView::Helpers::AssetTagHelper

  test "with host" do
    ActiveStorage.proxy_urls_host = "cdn.domain.com"
    assert_equal ActiveStorage.url_options(nil, :proxy), host: "cdn.domain.com"
    ActiveStorage.proxy_urls_host = nil
  end

  test "without host" do
    assert_equal ActiveStorage.url_options(nil, :proxy), only_path: true
  end
end

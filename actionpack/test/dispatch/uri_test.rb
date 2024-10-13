# frozen_string_literal: true

require "abstract_unit"

class URITest < ActiveSupport::TestCase
  test "create new url" do
    uri = ActionDispatch::Http::URI.new("http://myapp.test/page?id#me")
    assert_equal "http://myapp.test/page?id#me", uri.to_s
    assert_equal "http", uri.scheme
    assert_equal "http://", uri.protocol
    assert_equal "myapp.test", uri.host
    assert_equal "/page", uri.path
    assert_equal "me", uri.fragment
  end

  test "create with ipv6" do
    uri = ActionDispatch::Http::URI.new("http://[2001:0db8:85a3:0000:0000:8a2e:0370:7334]")
    assert_equal "http://[2001:0db8:85a3:0000:0000:8a2e:0370:7334]", uri.to_s
    uri = ActionDispatch::Http::URI.new("http://[2001:0db8:85a3:0000:0000:8a2e:0370:8a2e]:3000/home")
    assert_equal "http://[2001:0db8:85a3:0000:0000:8a2e:0370:8a2e]:3000/home", uri.to_s
  end

  test "extract domain and subdomains" do
    uri = ActionDispatch::Http::URI.new("http://sub.do.main.app.test/")
    assert_equal "sub.do.main", uri.subdomain
    assert_equal "sub.do", uri.subdomain(2)
    assert_equal "sub", uri.subdomain(3)
    assert_equal %w(sub do main), uri.subdomains
    assert_equal %w(sub), uri.subdomains(3)

    assert_equal "app.test", uri.domain
    assert_equal "main.app.test", uri.domain(2)
  end
end

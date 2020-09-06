# frozen_string_literal: true

require 'abstract_unit'

class SSLTest < ActionDispatch::IntegrationTest
  HEADERS = Rack::Utils::HeaderHash.new 'Content-Type' => 'text/html'

  attr_accessor :app

  def build_app(headers: {}, ssl_options: {})
    headers = HEADERS.merge(headers)
    ActionDispatch::SSL.new lambda { |env| [200, headers, []] }, **ssl_options.reverse_merge(hsts: { subdomains: true })
  end
end

class RedirectSSLTest < SSLTest
  def assert_not_redirected(url, headers: {}, redirect: {})
    self.app = build_app ssl_options: { redirect: redirect }
    get url, headers: headers
    assert_response :ok
  end

  def assert_redirected(redirect: {}, from: 'http://a/b?c=d', to: from.sub('http', 'https'))
    redirect = { body: [] }.merge(redirect)

    self.app = build_app ssl_options: { redirect: redirect }

    get from
    assert_response redirect[:status] || 301
    assert_redirected_to to
    assert_equal redirect[:body].join, @response.body
  end

  def assert_post_redirected(redirect: {}, from: 'http://a/b?c=d',
    to: from.sub('http', 'https'))

    self.app = build_app ssl_options: { redirect: redirect }

    post from
    assert_response redirect[:status] || 307
    assert_redirected_to to
  end

  test 'exclude can avoid redirect' do
    excluding = { exclude: -> request { request.path.match?(/healthcheck/) } }

    assert_not_redirected 'http://example.org/healthcheck', redirect: excluding
    assert_redirected from: 'http://example.org/', redirect: excluding
  end

  test 'https is not redirected' do
    assert_not_redirected 'https://example.org'
  end

  test 'proxied https is not redirected' do
    assert_not_redirected 'http://example.org', headers: { 'HTTP_X_FORWARDED_PROTO' => 'https' }
  end

  test 'http is redirected to https' do
    assert_redirected
  end

  test 'http POST is redirected to https with status 307' do
    assert_post_redirected
  end

  test 'redirect with custom status' do
    assert_redirected redirect: { status: 308 }
  end

  test 'redirect with ssl_default_redirect_status' do
    self.app = build_app(ssl_options: { ssl_default_redirect_status: 308 })

    get 'http://a/b?c=d'

    assert_response 301
    assert_redirected_to 'https://a/b?c=d'

    post 'http://a/b?c=d'

    assert_response 308
    assert_redirected_to 'https://a/b?c=d'
  end

  test 'redirect with custom body' do
    assert_redirected redirect: { body: ['foo'] }
  end

  test 'redirect to specific host' do
    assert_redirected redirect: { host: 'ssl' }, to: 'https://ssl/b?c=d'
  end

  test 'redirect to default port' do
    assert_redirected redirect: { port: 443 }
  end

  test 'redirect to non-default port' do
    assert_redirected redirect: { port: 8443 }, to: 'https://a:8443/b?c=d'
  end

  test 'redirect to different host and non-default port' do
    assert_redirected redirect: { host: 'ssl', port: 8443 }, to: 'https://ssl:8443/b?c=d'
  end

  test 'redirect to different host including port' do
    assert_redirected redirect: { host: 'ssl:443' }, to: 'https://ssl:443/b?c=d'
  end

  test 'no redirect with redirect set to false' do
    assert_not_redirected 'http://example.org', redirect: false
  end
end

class StrictTransportSecurityTest < SSLTest
  EXPECTED = 'max-age=63072000'
  EXPECTED_WITH_SUBDOMAINS = 'max-age=63072000; includeSubDomains'

  def assert_hsts(expected, url: 'https://example.org', hsts: { subdomains: true }, headers: {})
    self.app = build_app ssl_options: { hsts: hsts }, headers: headers
    get url
    if expected.nil?
      assert_nil response.headers['Strict-Transport-Security']
    else
      assert_equal expected, response.headers['Strict-Transport-Security']
    end
  end

  test 'enabled by default' do
    assert_hsts EXPECTED_WITH_SUBDOMAINS
  end

  test 'not sent with http:// responses' do
    assert_hsts nil, url: 'http://example.org'
  end

  test 'defers to app-provided header' do
    assert_hsts 'app-provided', headers: { 'Strict-Transport-Security' => 'app-provided' }
  end

  test 'hsts: true enables default settings' do
    assert_hsts EXPECTED_WITH_SUBDOMAINS, hsts: true
  end

  test 'hsts: false sets max-age to zero, clearing browser HSTS settings' do
    assert_hsts 'max-age=0; includeSubDomains', hsts: false
  end

  test ':expires sets max-age' do
    assert_hsts 'max-age=500; includeSubDomains', hsts: { expires: 500 }
  end

  test ':expires supports AS::Duration arguments' do
    assert_hsts 'max-age=31556952; includeSubDomains', hsts: { expires: 1.year }
  end

  test 'include subdomains' do
    assert_hsts "#{EXPECTED}; includeSubDomains", hsts: { subdomains: true }
  end

  test 'exclude subdomains' do
    assert_hsts EXPECTED, hsts: { subdomains: false }
  end

  test 'opt in to browser preload lists' do
    assert_hsts "#{EXPECTED_WITH_SUBDOMAINS}; preload", hsts: { preload: true }
  end

  test 'opt out of browser preload lists' do
    assert_hsts EXPECTED_WITH_SUBDOMAINS, hsts: { preload: false }
  end
end

class SecureCookiesTest < SSLTest
  DEFAULT = %(id=1; path=/\ntoken=abc; path=/; secure; HttpOnly)

  def get(**options)
    self.app = build_app(**options)
    super 'https://example.org'
  end

  def assert_cookies(*expected)
    assert_equal expected, response.headers['Set-Cookie'].split("\n")
  end

  def test_flag_cookies_as_secure
    get headers: { 'Set-Cookie' => DEFAULT }
    assert_cookies 'id=1; path=/; secure', 'token=abc; path=/; secure; HttpOnly'
  end

  def test_flag_cookies_as_secure_at_end_of_line
    get headers: { 'Set-Cookie' => 'problem=def; path=/; HttpOnly; secure' }
    assert_cookies 'problem=def; path=/; HttpOnly; secure'
  end

  def test_flag_cookies_as_secure_with_more_spaces_before
    get headers: { 'Set-Cookie' => 'problem=def; path=/; HttpOnly;  secure' }
    assert_cookies 'problem=def; path=/; HttpOnly;  secure'
  end

  def test_flag_cookies_as_secure_with_more_spaces_after
    get headers: { 'Set-Cookie' => 'problem=def; path=/; secure;  HttpOnly' }
    assert_cookies 'problem=def; path=/; secure;  HttpOnly'
  end

  def test_flag_cookies_as_secure_with_has_not_spaces_before
    get headers: { 'Set-Cookie' => 'problem=def; path=/;secure; HttpOnly' }
    assert_cookies 'problem=def; path=/;secure; HttpOnly'
  end

  def test_flag_cookies_as_secure_with_has_not_spaces_after
    get headers: { 'Set-Cookie' => 'problem=def; path=/; secure;HttpOnly' }
    assert_cookies 'problem=def; path=/; secure;HttpOnly'
  end

  def test_flag_cookies_as_secure_with_ignore_case
    get headers: { 'Set-Cookie' => 'problem=def; path=/; Secure; HttpOnly' }
    assert_cookies 'problem=def; path=/; Secure; HttpOnly'
  end

  def test_cookies_as_not_secure_with_secure_cookies_disabled
    get headers: { 'Set-Cookie' => DEFAULT }, ssl_options: { secure_cookies: false }
    assert_cookies(*DEFAULT.split("\n"))
  end

  def test_cookies_as_not_secure_with_exclude
    excluding = { exclude: -> request { /example/.match?(request.domain) } }
    get headers: { 'Set-Cookie' => DEFAULT }, ssl_options: { redirect: excluding }

    assert_cookies(*DEFAULT.split("\n"))
    assert_response :ok
  end

  def test_no_cookies
    get
    assert_nil response.headers['Set-Cookie']
  end

  def test_keeps_original_headers_behavior
    get headers: { 'Connection' => 'close' }
    assert_equal 'close', response.headers['Connection']
  end
end

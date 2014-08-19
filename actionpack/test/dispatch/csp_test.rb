require 'abstract_unit'

class CSPTest < ActionDispatch::IntegrationTest
  def default_app
    lambda { |env|
      headers = {'Content-Type' => "text/html"}
      [200, headers, ["OK"]]
    }
  end

  def app
    @app ||= ActionDispatch::CSP.new(default_app)
  end
  attr_writer :app

  def enforce_options
    @enforce_options ={
        default_src: :none,
        img_src: [:self, "example.com"],
        script_src: [:unsafe_eval, :unsafe_inline, "example.com", "cdn.example.org"],
        style_src: [:unsafe_eval, :unsafe_inline, "cdn.example.org"]
      }
  end

  def monitor_options
    @monitor_options ={
        default_src: :none,
        img_src: [:self, "example.com"],
        script_src: [:unsafe_eval, :unsafe_inline, "example.com", "cdn.example.org"],
        style_src: [:unsafe_eval, :unsafe_inline, "cdn.example.org"]
    }
  end

  def test_without_options
    get "http://example.org/"
    assert_not response.headers["Content-Security-Policy"]
    assert_not response.headers["Content-Security-Policy-Report-Only"]
  end

  def test_enforce
    self.app = ActionDispatch::CSP.new(default_app, enforce_options)
    get "http://example.org/"
    assert_equal "default-src 'none';img-src 'self' example.com;script-src 'unsafe-eval' 'unsafe-inline' example.com cdn.example.org;style-src 'unsafe-eval' 'unsafe-inline' cdn.example.org;", response.headers["Content-Security-Policy"]
    assert_not response.headers["Content-Security-Policy-Report-Only"]
  end

  def test_monitor
    self.app = ActionDispatch::CSP.new(default_app,{},monitor_options)
    get "http://example.org/"
    assert_not response.headers["Content-Security-Policy"]
    assert_equal "default-src 'none';img-src 'self' example.com;script-src 'unsafe-eval' 'unsafe-inline' example.com cdn.example.org;style-src 'unsafe-eval' 'unsafe-inline' cdn.example.org;", response.headers["Content-Security-Policy-Report-Only"]
  end

  def test_both_enforce_and_monitor
    self.app = ActionDispatch::CSP.new(default_app, enforce_options, monitor_options)
    get "http://example.org/"
    assert_equal "default-src 'none';img-src 'self' example.com;script-src 'unsafe-eval' 'unsafe-inline' example.com cdn.example.org;style-src 'unsafe-eval' 'unsafe-inline' cdn.example.org;", response.headers["Content-Security-Policy"]
    assert_equal "default-src 'none';img-src 'self' example.com;script-src 'unsafe-eval' 'unsafe-inline' example.com cdn.example.org;style-src 'unsafe-eval' 'unsafe-inline' cdn.example.org;", response.headers["Content-Security-Policy-Report-Only"]
  end

  def test_report_uri
    options = {
      report_uri: "/csp_reporter"
    }
    self.app = ActionDispatch::CSP.new(default_app, options, options)
    get "http://example.org/"
    assert response.headers["Content-Security-Policy"].include?("report-uri /csp_reporter;")
    assert response.headers["Content-Security-Policy-Report-Only"].include?("report-uri /csp_reporter;")
  end

end
require 'abstract_unit'

class BestStandardsSupportTest < ActiveSupport::TestCase
  def test_with_best_standards_support
    _, headers, _ = app(true, {}).call({})
    assert_equal "IE=Edge,chrome=1", headers["X-UA-Compatible"]
  end

  def test_with_builtin_best_standards_support
    _, headers, _ = app(:builtin, {}).call({})
    assert_equal "IE=Edge", headers["X-UA-Compatible"]
  end

  def test_without_best_standards_support
    _, headers, _ = app(false, {}).call({})
    assert_equal nil, headers["X-UA-Compatible"]
  end

  def test_appends_to_app_headers
    app_headers = { "X-UA-Compatible" => "requiresActiveX=true" }
    _, headers, _ = app(true, app_headers).call({})

    expects = "requiresActiveX=true,IE=Edge,chrome=1"
    assert_equal expects, headers["X-UA-Compatible"]
  end

  private

    def app(type, headers)
      app = proc { [200, headers, "response"] }
      ActionDispatch::BestStandardsSupport.new(app, type)
    end

end

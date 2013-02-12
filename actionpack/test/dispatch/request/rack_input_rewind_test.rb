require 'abstract_unit'

class RackInputRewindTest < ActionDispatch::IntegrationTest
  class InputReader
    def call(env)
      result = env['rack.input'].read
      [200, {"Content-Type" => "text/plain"}, [result]]
    end
  end

  test "request.body is rewound if while parsing XML parameters" do
    req = Rack::MockRequest.new(ActionDispatch::ParamsParser.new(InputReader.new))
    input = "<foo>bar</foo>"
    resp = req.post('/', "CONTENT_TYPE" => "application/xml", :input => input)
    assert !resp.body.empty?, "rack.input was not rewound properly by ParamsParser middleware"
  end

  test "request.body is rewound while parsing JSONparameters" do
    req = Rack::MockRequest.new(ActionDispatch::ParamsParser.new(InputReader.new))
    input = "{\"person\": {\"name\": \"David\"}}"
    resp = req.post('/', "CONTENT_TYPE" => "application/json", :input => input )
    assert !resp.body.empty?, "rack.input was not rewound properly by ParamsParser middleware"
  end

end

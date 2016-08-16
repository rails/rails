require "abstract_unit"

class MultipartParamsParsingTest < ActionDispatch::IntegrationTest
  class TestController < ActionController::Base
    class << self
      attr_accessor :last_request_parameters, :last_parameters
    end

    def parse
      self.class.last_request_parameters = begin
        request.request_parameters
      rescue EOFError
        {}
      end
      self.class.last_parameters = request.parameters
      head :ok
    end

    def read
      render plain: "File: #{params[:uploaded_data].read}"
    end
  end

  FIXTURE_PATH = File.dirname(__FILE__) + "/../../fixtures/multipart"

  def teardown
    TestController.last_request_parameters = nil
  end

  test "parses single parameter" do
    assert_equal({ "foo" => "bar" }, parse_multipart("single_parameter"))
  end

  test "parses bracketed parameters" do
    assert_equal({ "foo" => { "baz" => "bar" } }, parse_multipart("bracketed_param"))
  end

  test "parse single utf8 parameter" do
    assert_equal({ "Iñtërnâtiônàlizætiøn_name" => "Iñtërnâtiônàlizætiøn_value" },
                 parse_multipart("single_utf8_param"), "request.request_parameters")
    assert_equal(
      "Iñtërnâtiônàlizætiøn_value",
      TestController.last_parameters["Iñtërnâtiônàlizætiøn_name"], "request.parameters")
  end

  test "parse bracketed utf8 parameter" do
    assert_equal({ "Iñtërnâtiônàlizætiøn_name" => {
      "Iñtërnâtiônàlizætiøn_nested_name" => "Iñtërnâtiônàlizætiøn_value" } },
      parse_multipart("bracketed_utf8_param"), "request.request_parameters")
    assert_equal(
      { "Iñtërnâtiônàlizætiøn_nested_name" => "Iñtërnâtiônàlizætiøn_value" },
      TestController.last_parameters["Iñtërnâtiônàlizætiøn_name"], "request.parameters")
  end

  test "parses text file" do
    params = parse_multipart("text_file")
    assert_equal %w(file foo), params.keys.sort
    assert_equal "bar", params["foo"]

    file = params["file"]
    assert_equal "file.txt", file.original_filename
    assert_equal "text/plain", file.content_type
    assert_equal "contents", file.read
  end

  test "parses utf8 filename with percent character" do
    params = parse_multipart("utf8_filename")
    assert_equal %w(file foo), params.keys.sort
    assert_equal "bar", params["foo"]

    file = params["file"]
    assert_equal "ファイル%名.txt", file.original_filename
    assert_equal "text/plain", file.content_type
    assert_equal "contents", file.read
  end

  test "parses boundary problem file" do
    params = parse_multipart("boundary_problem_file")
    assert_equal %w(file foo), params.keys.sort

    file = params["file"]
    foo  = params["foo"]

    assert_equal "file.txt", file.original_filename
    assert_equal "text/plain", file.content_type

    assert_equal "bar", foo
  end

  test "parses large text file" do
    params = parse_multipart("large_text_file")
    assert_equal %w(file foo), params.keys.sort
    assert_equal "bar", params["foo"]

    file = params["file"]

    assert_equal "file.txt", file.original_filename
    assert_equal "text/plain", file.content_type
    assert_equal(("a" * 20480), file.read)
  end

  test "parses binary file" do
    params = parse_multipart("binary_file")
    assert_equal %w(file flowers foo), params.keys.sort
    assert_equal "bar", params["foo"]

    file = params["file"]
    assert_equal "file.csv", file.original_filename
    assert_nil file.content_type
    assert_equal "contents", file.read

    file = params["flowers"]
    assert_equal "flowers.jpg", file.original_filename
    assert_equal "image/jpeg", file.content_type
    assert_equal 19512, file.size
  end

  test "parses mixed files" do
    params = parse_multipart("mixed_files")
    assert_equal %w(files foo), params.keys.sort
    assert_equal "bar", params["foo"]

    # Rack doesn't handle multipart/mixed for us.
    files = params["files"]
    assert_equal 19756, files.bytesize
  end

  test "does not create tempfile if no file has been selected" do
    params = parse_multipart("none")
    assert_equal %w(submit-name), params.keys.sort
    assert_equal "Larry", params["submit-name"]
    assert_equal nil, params["files"]
  end

  test "parses empty upload file" do
    params = parse_multipart("empty")
    assert_equal %w(files submit-name), params.keys.sort
    assert_equal "Larry", params["submit-name"]
    assert params["files"]
    assert_equal "", params["files"].read
  end

  test "uploads and reads binary file" do
    with_test_routing do
      fixture = FIXTURE_PATH + "/mona_lisa.jpg"
      params = { uploaded_data: fixture_file_upload(fixture, "image/jpg") }
      post "/read", params: params
    end
  end

  test "uploads and reads file" do
    with_test_routing do
      post "/read", params: { uploaded_data: fixture_file_upload(FIXTURE_PATH + "/hello.txt", "text/plain") }
      assert_equal "File: Hello", response.body
    end
  end

  # This can happen in Internet Explorer when redirecting after multipart form submit.
  test "does not raise EOFError on GET request with multipart content-type" do
    with_routing do |set|
      set.draw do
        ActiveSupport::Deprecation.silence do
          get ":action", controller: "multipart_params_parsing_test/test"
        end
      end
      headers = { "CONTENT_TYPE" => "multipart/form-data; boundary=AaB03x" }
      get "/parse", headers: headers
      assert_response :ok
    end
  end

  private
    def fixture(name)
      File.open(File.join(FIXTURE_PATH, name), "rb") do |file|
        { "rack.input" => file.read,
          "CONTENT_TYPE" => "multipart/form-data; boundary=AaB03x",
          "CONTENT_LENGTH" => file.stat.size.to_s }
      end
    end

    def parse_multipart(name)
      with_test_routing do
        headers = fixture(name)
        post "/parse", params: headers.delete("rack.input"), headers: headers
        assert_response :ok
        TestController.last_request_parameters
      end
    end

    def with_test_routing
      with_routing do |set|
        set.draw do
          ActiveSupport::Deprecation.silence do
            post ":action", controller: "multipart_params_parsing_test/test"
          end
        end
        yield
      end
    end
end

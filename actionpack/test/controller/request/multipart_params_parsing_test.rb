require 'abstract_unit'

class MultipartParamsParsingTest < ActionController::IntegrationTest
  class TestController < ActionController::Base
    class << self
      attr_accessor :last_request_parameters, :last_request_type
    end

    def parse
      self.class.last_request_type = ActionController::Base.param_parsers[request.content_type]
      self.class.last_request_parameters = request.request_parameters
      head :ok
    end

    def read
      render :text => "File: #{params[:uploaded_data].read}"
    end
  end

  FIXTURE_PATH = File.dirname(__FILE__) + '/../../fixtures/multipart'

  def teardown
    TestController.last_request_parameters = nil
    TestController.last_request_type = nil
  end

  test "parses single parameter" do
    assert_equal({ 'foo' => 'bar' }, parse_multipart('single_parameter'))
  end

  test "parses bracketed parameters" do
    assert_equal({ 'foo' => { 'baz' => 'bar'}}, parse_multipart('bracketed_param'))
  end

  test "parses text file" do
    params = parse_multipart('text_file')
    assert_equal %w(file foo), params.keys.sort
    assert_equal 'bar', params['foo']

    file = params['file']
    assert_kind_of StringIO, file
    assert_equal 'file.txt', file.original_filename
    assert_equal "text/plain", file.content_type
    assert_equal 'contents', file.read
  end

  test "parses boundary problem file" do
    params = parse_multipart('boundary_problem_file')
    assert_equal %w(file foo), params.keys.sort

    file = params['file']
    foo  = params['foo']

    assert_kind_of Tempfile, file

    assert_equal 'file.txt', file.original_filename
    assert_equal "text/plain", file.content_type

    assert_equal 'bar', foo
  end

  test "parses large text file" do
    params = parse_multipart('large_text_file')
    assert_equal %w(file foo), params.keys.sort
    assert_equal 'bar', params['foo']

    file = params['file']

    assert_kind_of Tempfile, file

    assert_equal 'file.txt', file.original_filename
    assert_equal "text/plain", file.content_type
    assert ('a' * 20480) == file.read
  end

  test "parses binary file" do
    params = parse_multipart('binary_file')
    assert_equal %w(file flowers foo), params.keys.sort
    assert_equal 'bar', params['foo']

    file = params['file']
    assert_kind_of StringIO, file
    assert_equal 'file.csv', file.original_filename
    assert_nil file.content_type
    assert_equal 'contents', file.read

    file = params['flowers']
    assert_kind_of StringIO, file
    assert_equal 'flowers.jpg', file.original_filename
    assert_equal "image/jpeg", file.content_type
    assert_equal 19512, file.size
  end

  test "parses mixed files" do
    params = parse_multipart('mixed_files')
    assert_equal %w(files foo), params.keys.sort
    assert_equal 'bar', params['foo']

    # Ruby CGI doesn't handle multipart/mixed for us.
    files = params['files']
    assert_kind_of String, files
    files.force_encoding('ASCII-8BIT') if files.respond_to?(:force_encoding)
    assert_equal 19756, files.size
  end

  test "uploads and parses parameters" do
    with_test_routing do
      params = { :uploaded_data => fixture_file_upload(FIXTURE_PATH + "/mona_lisa.jpg", "image/jpg") }
      post '/parse', params, :location => 'blah'
      assert_equal(:multipart_form, TestController.last_request_type)
    end
  end

  test "uploads and reads file" do
    with_test_routing do
      post '/read', :uploaded_data => fixture_file_upload(FIXTURE_PATH + "/hello.txt", "text/plain")
      assert_equal "File: Hello", response.body
    end
  end

  # The lint wrapper is used in integration tests
  # instead of a normal StringIO class
  InputWrapper = Rack::Lint::InputWrapper

  test "parses unwindable stream" do
    InputWrapper.any_instance.expects(:rewind).raises(Errno::ESPIPE)
    params = parse_multipart('large_text_file')
    assert_equal %w(file foo), params.keys.sort
    assert_equal 'bar', params['foo']
  end

  test "uploads and reads file with unwindable input" do
    InputWrapper.any_instance.expects(:rewind).raises(Errno::ESPIPE)

    with_test_routing do
      post '/read', :uploaded_data => fixture_file_upload(FIXTURE_PATH + "/hello.txt", "text/plain")
      assert_equal "File: Hello", response.body
    end
  end

  private
    def fixture(name)
      File.open(File.join(FIXTURE_PATH, name), 'rb') do |file|
        { "rack.input" => file.read,
          "CONTENT_TYPE" => "multipart/form-data; boundary=AaB03x",
          "CONTENT_LENGTH" => file.stat.size.to_s }
      end
    end

    def parse_multipart(name)
      with_test_routing do
        headers = fixture(name)
        post "/parse", headers.delete("rack.input"), headers
        assert_response :ok
        TestController.last_request_parameters
      end
    end

    def with_test_routing
      with_routing do |set|
        set.draw do |map|
          map.connect ':action', :controller => "multipart_params_parsing_test/test"
        end
        yield
      end
    end
end

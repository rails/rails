require 'abstract_unit'

unless defined? ApplicationController
  class ApplicationController < ActionController::Base
  end
end

class UploadTestController < ActionController::Base
  def update
    SessionUploadTest.last_request_type = ActionController::Base.param_parsers[request.content_type]
    render :text => "got here"
  end

  def read
    render :text => "File: #{params[:uploaded_data].read}"
  end
end

class SessionUploadTest < ActionController::IntegrationTest
  FILES_DIR = File.dirname(__FILE__) + '/../fixtures/multipart'

  class << self
    attr_accessor :last_request_type
  end

  def test_upload_and_read_file
    with_test_routing do
      post '/read', :uploaded_data => fixture_file_upload(FILES_DIR + "/hello.txt", "text/plain")
      assert_equal "File: Hello", response.body
    end
  end

  # The lint wrapper is used in integration tests
  # instead of a normal StringIO class
  InputWrapper = Rack::Lint::InputWrapper

  def test_post_with_upload_with_unrewindable_input
    InputWrapper.any_instance.expects(:rewind).raises(Errno::ESPIPE)

    with_test_routing do
      post '/read', :uploaded_data => fixture_file_upload(FILES_DIR + "/hello.txt", "text/plain")
      assert_equal "File: Hello", response.body
    end
  end

  def test_post_with_upload_with_params_parsing
    with_test_routing do
      params = { :uploaded_data => fixture_file_upload(FILES_DIR + "/mona_lisa.jpg", "image/jpg") }
      post '/update', params, :location => 'blah'
      assert_equal(:multipart_form, SessionUploadTest.last_request_type)
    end
  end

  private
    def with_test_routing
      with_routing do |set|
        set.draw do |map|
          map.update 'update', :controller => "upload_test", :action => "update", :method => :post
          map.read 'read', :controller => "upload_test", :action => "read", :method => :post
        end

        yield
      end
    end
end

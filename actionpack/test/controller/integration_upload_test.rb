require 'abstract_unit'
require 'action_controller/integration'
require 'action_controller/routing'

unless defined? ApplicationController
  class ApplicationController < ActionController::Base
  end
end

class UploadTestController < ActionController::Base
  session :off

  def update
    SessionUploadTest.last_request_type = ActionController::Base.param_parsers[request.content_type]
    render :text => "got here"
  end
end

class SessionUploadTest < ActionController::IntegrationTest
  FILES_DIR = File.dirname(__FILE__) + '/../fixtures/multipart'

  class << self
    attr_accessor :last_request_type
  end

  # def setup
  #   @session = ActionController::Integration::Session.new
  # end
  def test_post_with_upload
    uses_mocha "test_post_with_upload" do
      Dependencies.stubs(:load?).returns(false)
      with_routing do |set|
        set.draw do |map|
          map.update 'update', :controller => "upload_test", :action => "update", :method => :post
        end

        params = { :uploaded_data => fixture_file_upload(FILES_DIR + "/mona_lisa.jpg", "image/jpg") }
        post '/update', params, :location => 'blah'
        assert_equal(:multipart_form, SessionUploadTest.last_request_type)
      end
    end
   end
end

require File.dirname(__FILE__) + '/../abstract_unit'
require 'logger'
require 'test/unit'
require 'cgi'
require 'stringio'

DEBUG=false

def test_logger
  if DEBUG then ActionController::Base.logger = Logger.new(STDERR)
  else ActionController::Base.logger = Logger.new(StringIO.new)
  end
end

# Provide a static version of the Controllers module instead of the auto-loading version.
# We don't want these tests to fail when dependencies are to blame.
module Controllers
  class EmptyController < ActionController::Base
  end
  class ApplicationController < ActionController::Base
  end

  class MockController < ActionController::Base
    def initialize
      super
      @session = {:uploads => {}}
      @params = {}
    end
  end
  
  class SingleUploadController < ActionController::Base
    upload_status_for   :one
    
    def one; end
  end

  class DoubleUploadController < ActionController::Base
    upload_status_for   :one, :two
    
    def one; end
    def two; end
  end
  
  class DoubleStatusUploadController < ActionController::Base
    upload_status_for   :one, :two, :status => :custom_status
    
    def one; end
    def two; end
  end
  
  class DoubleSeperateController < ActionController::Base
    upload_status_for :one
    upload_status_for :two
    
    def one; end    
    def two; end
  end  
  
  class UploadController < ActionController::Base
    upload_status_for   :norendered, :rendered, :redirected, :finish_param_dict, :finish_param_string, :finish_param_number
    
    def norendered 
    end
      
    def rendered
      render_text("rendered")
    end
    
    def redirected
      redirect_to "/redirected/"
    end
    
    def finish_param_dict
      finish_upload_status "{a: 'b'}"
    end

    def finish_param_string
      finish_upload_status "'a string'"
    end

    def finish_param_number
      finish_upload_status 123
    end

    def finish_param_number_redirect
      redirect_to "/redirected/"
      finish_upload_status 123
    end
  end
end

class MockIO < StringIO
  def initialize(data='', &block)
    test_logger.debug("MockIO inializing data: #{data[0..20]}")

    @block = block
    super(data)
  end

  def write(data)
    test_logger.debug("MockIO write #{data.size} data: #{data[0..20]}")
    super
  end
  def read(size)
    test_logger.debug("MockIO getting data from super")
    data = super

    test_logger.debug("Calling read callback")
    @block.call 

    test_logger.debug("Returning data: #{data.size}")
    data
  end
end

class MockCGI < CGI
  BOUNDARY = '----------0xKhTmLbOuNdArY'
  FILENAME = 'dummy.nul'

  attr_reader :upload_id, :session_options, :session_id

  def initialize(size=1000, url='/test', &block)
    @url = url
    @env = {}
    @sio = MockIO.new('') { block.call(self) if block_given? }

    @upload_id = '1'

    add_param('param1', 'value1')
    add_data(size)
    add_param('param1', 'value2')
    add_end_boundary
    init_env
    @sio.rewind
    super()
  end

  #def stdinput_without_progress
  #  @sio
  #end

  def stdinput
    @sio
  end
  
  def env_table
    @env
  end

  private
  def init_env
    @env['HTTP_HOST'] = 'localhost'
    @env['SERVER_PORT'] = '80'
    @env['REQUEST_METHOD'] = "POST"
    @env['QUERY_STRING'] = @url.split('?')[1] || "upload_id=#{upload_id}&query_param=query_value"
    @env['REQUEST_URI'] = @url
    @env['SCRIPT_NAME'] = @url.split('?').first.split('/').last
    @env['PATH_INFO'] = @url.split('?').first
    @env['CONTENT_TYPE'] = "multipart/form-data; boundary=#{BOUNDARY}"
    @env['CONTENT_LENGTH'] = @sio.tell - EOL.size

    @session_options = ActionController::CgiRequest::DEFAULT_SESSION_OPTIONS.inject({}) { |options, pair| 
      options[pair.first.to_s] = pair.last; options 
    }
    session = CGI::Session.new({}, @session_options.merge({'new_session' => true}))
    @session_id = session.session_id
    @env['COOKIE'] = "_session_id=#{session.session_id}"
    session.close
  end

  def add_param(name, value)
    add_boundary
    @sio << "Content-Disposition: form-data; name=\"#{name}\"" << EOL << EOL
    @sio << value.to_s << EOL
  end

  def add_data(size)
    add_boundary
    @sio << "Content-Disposition: form-data; name=\"file\"; filename=\"#{FILENAME}\"" << EOL
    @sio << "Content-Type: application/octet-stream" << EOL << EOL
    @sio << "." * size
    @sio << EOL
  end

  def add_boundary
    @sio << "--" << BOUNDARY << EOL
  end

  def add_end_boundary
    @sio << "--" << BOUNDARY << "--" << EOL
  end
end

class MultipartProgressTest < Test::Unit::TestCase
  
  def test_domain_language_single
    c = Controllers::SingleUploadController.new
    assert_respond_to(c, :one)
    assert_respond_to(c, :upload_status)
    assert_respond_to(c, :finish_upload_status)
  end
  
  def test_domain_language_double
    c = Controllers::DoubleUploadController.new
    assert_respond_to(c, :one)
    assert_respond_to(c, :two)
    assert_respond_to(c, :upload_status)
    assert_respond_to(c, :finish_upload_status)
  end
    
  def test_domain_language_double_status
    c = Controllers::DoubleStatusUploadController.new
    assert_respond_to(c, :one)
    assert_respond_to(c, :two)
    assert_respond_to(c, :custom_status)
    assert_respond_to(c, :finish_upload_status)
  end
    
  def test_domain_language_double_seperate
    c = Controllers::DoubleSeperateController.new
    assert_respond_to(c, :one)
    assert_respond_to(c, :two)
    assert_respond_to(c, :upload_status)
    assert_respond_to(c, :finish_upload_status)
  end

  def test_finish_status_norendered
    # Fails to render the upload finish script because there is no view associated with this action
    test_logger.debug('test_finish_status_norendered')

    res = process(:action => 'norendered', :upload_id => 1)
    assert_match(/ActionView::ActionViewError/s, res.body)
    
    res = process(:action => :upload_status, :upload_id => 1)
    assert_match(/Upload finished/s, res.body)

    res = process(:action => :norendered)
    assert_match(/ActionView::ActionViewError/s, res.body)
  end

  def test_finish_status_rendered
    test_logger.debug('test_finish_status_rendered')

    res = process(:action => :rendered, :upload_id => 1)
    assert_match(/stop\(\)/s, res.body)
    assert_no_match(/rendered/s, res.body)
    
    res = process(:action => :upload_status, :upload_id => 1)
    assert_match(/Upload finished/s, res.body)
    
    res = process(:action => :rendered)
    assert_no_match(/stop\(\)/s, res.body)
    assert_match(/rendered/, res.body)
  end 
  
  def test_finish_status_redirected
    test_logger.debug('test_finish_status_redirected')

    res = process(:action => :redirected, :upload_id => 1)
    assert_match(/location\.replace/s, res.body)
    
    res = process(:action => :redirected)
    assert_no_match(/location\.replace/s, res.body)
    assert_match(/\/redirected\//s, res.headers['location'])
    assert_match(/302 .*$/, res.headers['Status'])

    res = process(:action => :upload_status, :upload_id => 1)
    assert_match(/Upload finished/s, res.body)
  end
  
  def test_finish_status_finish_param
    test_logger.debug('test_finish_status_param')

    res = process(:action => :finish_param_string, :upload_id => 1)
    assert_match(/stop\('a string'\)/s, res.body)
    assert_no_redirect res

    res = process(:action => :finish_param_dict, :upload_id => 1)
    assert_match(/stop\(\{a: 'b'\}\)/s, res.body)
    assert_no_redirect res

    res = process(:action => :finish_param_number, :upload_id => 1)
    assert_match(/stop\(123\)/s, res.body)
    assert_no_redirect res

    res = process(:action => :finish_param_number_redirect, :upload_id => 1)
    test_logger.debug('test_finish_status_param: ' + res.body)
    assert_match(/stop\(123\)/s, res.body)
    assert_match(/replace\('\http:\/\/localhost\/redirected\/'\).*?/s, res.body)
    assert_no_redirect res
  end
  
  def test_basic_setup
    test_logger.debug('test_basic_setup')

    cgi, request, response = new_request(100000)
    assert_not_nil(request.session)
    assert_not_nil(request.session[:uploads], "uploads collection not set")
    assert_not_nil(request.session[:uploads][cgi.upload_id], "upload id not set")
    progress = request.session[:uploads][cgi.upload_id]
    assert_equal(true, progress.finished?)
  end

  def test_params
    test_logger.debug('test_params')

    cgi, request, response = new_request(1000)
    assert(!request.params.empty?)
    assert(!request.params['param1'].empty?)
  end

  def test_share_session
    cgi, request, response = new_request(100000) do |cgi, req|
      if cgi.stdinput.tell > 50000
        # force a save
        cgi.stdinput.save_progress rescue flunk('Something else is wrong, our wrapper isnt setup, is ActionController::Base.logger set?')

        other_session = CGI::Session.new(cgi, cgi.session_options.merge({'session_id' => cgi.session_id}))
        assert_not_nil(other_session[:uploads])
        assert_not_nil(other_session[:uploads][cgi.upload_id])
        assert_in_delta(cgi.stdinput.session[:uploads][cgi.upload_id].bitrate, other_session[:uploads][cgi.upload_id].bitrate, 1000.0, "Seperate session does not share data from original session")

        other_session.close
      end
    end
  end

  def test_upload_ids
    c = Controllers::MockController.new
    (1..222).each do |id|
      c.params = {}

      assert_equal((id-1).to_s, c.last_upload_id, "last_upload_id is out of sync")
      assert_equal(id.to_s, c.next_upload_id, "next_upload_id is out of sync")
      assert_equal(id.to_s, c.current_upload_id, "current_upload_id is out of sync")

      c.params = {:upload_id => (id-1).to_s}
      assert_equal((id-1).to_s, c.current_upload_id, "current_upload_id is out of sync")

      c.session[:uploads][id] = {}
    end
  end

  private
  def new_request(size=1000, url='/test', &block)
    test_logger.debug('Creating MockCGI')
    cgi = MockCGI.new(size, url) do |cgi|
      block.call(cgi) if block_given?
    end

    assert(cgi.private_methods.include?("read_multipart_with_progress")) 
    return [cgi, ActionController::CgiRequest.new(cgi), ActionController::CgiResponse.new(cgi)]
  end

  def process(options = {})
    Controllers::UploadController.process(*(new_request(1000, '/upload?' + options.map {|k,v| "#{k}=#{v}"}.join('&'))[1..2]))
  end

  def assert_no_redirect(res)
    assert_nil(res.redirected_to)
    assert_nil(res.headers['location'])
    assert_match(/200 .*$/, res.headers['Status'])
  end

end

require 'abstract_unit'

module ShowExceptions
  class ShowExceptionsController < ActionController::Base
    use ActionDispatch::ShowExceptions
    use ActionDispatch::DebugExceptions

    def boom
      raise 'boom!'
    end
  end

  class ShowExceptionsTest < ActionDispatch::IntegrationTest
    test 'show error page from a remote ip' do
      @app = ShowExceptionsController.action(:boom)
      self.remote_addr = '208.77.188.166'
      get '/'
      assert_equal "500 error fixture\n", body
    end

    test 'show diagnostics from a local ip' do
      @app = ShowExceptionsController.action(:boom)
      ['127.0.0.1', '127.0.0.127', '::1', '0:0:0:0:0:0:0:1', '0:0:0:0:0:0:0:1%0'].each do |ip_address|
        self.remote_addr = ip_address
        get '/'
        assert_match(/boom/, body)
      end
    end

    test 'show diagnostics from a remote ip when consider_all_requests_local is true' do
      ShowExceptionsController.any_instance.stubs(:consider_all_requests_local).returns(true)
      @app = ShowExceptionsController.action(:boom)
      self.remote_addr = '208.77.188.166'
      get '/'
      assert_match(/boom/, body)
    end
  end

  class ShowExceptionsOverridenController < ShowExceptionsController
    private

    def show_detailed_exceptions?
      params['detailed'] == '1'
    end
  end

  class ShowExceptionsOverridenTest < ActionDispatch::IntegrationTest
    test 'show error page' do
      @app = ShowExceptionsOverridenController.action(:boom)
      get '/', {'detailed' => '0'}
      assert_equal "500 error fixture\n", body
    end

    test 'show diagnostics message' do
      @app = ShowExceptionsOverridenController.action(:boom)
      get '/', {'detailed' => '1'}
      assert_match(/boom/, body)
    end
  end
end

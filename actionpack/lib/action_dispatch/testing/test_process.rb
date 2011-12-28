require 'action_dispatch/middleware/cookies'
require 'action_dispatch/middleware/flash'
require 'active_support/core_ext/hash/indifferent_access'

module ActionDispatch
  module TestProcess
    def assigns(key = nil)
      assigns = @controller.view_assigns.with_indifferent_access
      key.nil? ? assigns : assigns[key]
    end

    def session
      @request.session
    end

    def flash
      @request.flash
    end

    def cookies
      @request.cookie_jar
    end

    def redirect_to_url
      @response.redirect_url
    end

    # Shortcut for <tt>Rack::Test::UploadedFile.new(ActionController::TestCase.fixture_path + path, type)</tt>:
    #
    #   post :change_avatar, :avatar => fixture_file_upload('/files/spongebob.png', 'image/png')
    #
    # To upload binary files on Windows, pass <tt>:binary</tt> as the last parameter.
    # This will not affect other platforms:
    #
    #   post :change_avatar, :avatar => fixture_file_upload('/files/spongebob.png', 'image/png', :binary)
    def fixture_file_upload(path, mime_type = nil, binary = false)
      fixture_path = self.class.fixture_path if self.class.respond_to?(:fixture_path)
      Rack::Test::UploadedFile.new("#{fixture_path}#{path}", mime_type, binary)
    end
  end
end

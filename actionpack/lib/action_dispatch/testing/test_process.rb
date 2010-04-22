require 'action_dispatch/middleware/flash'
require 'active_support/core_ext/hash/indifferent_access'

module ActionDispatch
  module TestProcess
    def assigns(key = nil)
      assigns = {}.with_indifferent_access
      @controller.instance_variable_names.each do |ivar|
        next if ActionController::Base.protected_instance_variables.include?(ivar)
        assigns[ivar[1..-1]] = @controller.instance_variable_get(ivar)
      end

      key.nil? ? assigns : assigns[key]
    end

    def session
      @request.session
    end

    def flash
      @request.flash
    end

    def cookies
      @request.cookies.merge(@response.cookies)
    end

    def redirect_to_url
      @response.redirect_url
    end

    # Shortcut for <tt>ARack::Test::UploadedFile.new(ActionController::TestCase.fixture_path + path, type)</tt>:
    #
    #   post :change_avatar, :avatar => fixture_file_upload('/files/spongebob.png', 'image/png')
    #
    # To upload binary files on Windows, pass <tt>:binary</tt> as the last parameter.
    # This will not affect other platforms:
    #
    #   post :change_avatar, :avatar => fixture_file_upload('/files/spongebob.png', 'image/png', :binary)
    def fixture_file_upload(path, mime_type = nil, binary = false)
      fixture_path = ActionController::TestCase.send(:fixture_path) if ActionController::TestCase.respond_to?(:fixture_path)
      Rack::Test::UploadedFile.new("#{fixture_path}#{path}", mime_type, binary)
    end
  end
end

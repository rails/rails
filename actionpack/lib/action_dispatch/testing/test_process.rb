# frozen_string_literal: true

# :markup: markdown

require "action_dispatch/middleware/cookies"
require "action_dispatch/middleware/flash"

module ActionDispatch
  module TestProcess
    module FixtureFile
      # Shortcut for
      # `Rack::Test::UploadedFile.new(File.join(ActionDispatch::IntegrationTest.file_fixture_path, path), type)`:
      #
      #     post :change_avatar, params: { avatar: file_fixture_upload('david.png', 'image/png') }
      #
      # Default fixture files location is `test/fixtures/files`.
      #
      # To upload binary files on Windows, pass `:binary` as the last parameter. This
      # will not affect other platforms:
      #
      #     post :change_avatar, params: { avatar: file_fixture_upload('david.png', 'image/png', :binary) }
      def file_fixture_upload(path, mime_type = nil, binary = false)
        if self.class.file_fixture_path && !File.exist?(path)
          path = file_fixture(path)
        end

        Rack::Test::UploadedFile.new(path, mime_type, binary)
      end
      alias_method :fixture_file_upload, :file_fixture_upload
    end

    include FixtureFile

    def assigns(key = nil)
      raise NoMethodError,
        'assigns has been extracted to a gem. To continue using it,
        add `gem "rails-controller-testing"` to your Gemfile.'
    end

    def session
      @request.session
    end

    def flash
      @request.flash
    end

    def cookies
      @cookie_jar ||= Cookies::CookieJar.build(@request, @request.cookies)
    end

    def redirect_to_url
      @response.redirect_url
    end
  end
end

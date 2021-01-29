# frozen_string_literal: true

require "action_dispatch/middleware/cookies"
require "action_dispatch/middleware/flash"

module ActionDispatch
  module TestProcess
    module FixtureFile
      # Shortcut for <tt>Rack::Test::UploadedFile.new(File.join(ActionDispatch::IntegrationTest.file_fixture_path, path), type)</tt>:
      #
      #   post :change_avatar, params: { avatar: fixture_file_upload('spongebob.png', 'image/png') }
      #
      # Default fixture files location is <tt>test/fixtures/files</tt>.
      #
      # To upload binary files on Windows, pass <tt>:binary</tt> as the last parameter.
      # This will not affect other platforms:
      #
      #   post :change_avatar, params: { avatar: fixture_file_upload('spongebob.png', 'image/png', :binary) }
      def fixture_file_upload(path, mime_type = nil, binary = false)
        if self.class.respond_to?(:fixture_path) && self.class.fixture_path &&
            !File.exist?(path)
          original_path = path
          path = Pathname.new(self.class.fixture_path).join(path)

          if !self.class.file_fixture_path
            ActiveSupport::Deprecation.warn(<<~EOM)
              Passing a path to `fixture_file_upload` relative to `fixture_path` is deprecated.
              In Rails 6.2, the path needs to be relative to `file_fixture_path` which you
              haven't set yet. Set `file_fixture_path` to discard this warning.
            EOM
          elsif path.exist?
            non_deprecated_path = Pathname(File.absolute_path(path)).relative_path_from(Pathname(File.absolute_path(self.class.file_fixture_path)))
            ActiveSupport::Deprecation.warn(<<~EOM)
              Passing a path to `fixture_file_upload` relative to `fixture_path` is deprecated.
              In Rails 6.2, the path needs to be relative to `file_fixture_path`.

              Please modify the call from
              `fixture_file_upload("#{original_path}")` to `fixture_file_upload("#{non_deprecated_path}")`.
            EOM
          else
            path = file_fixture(original_path)
          end
        elsif self.class.file_fixture_path && !File.exist?(path)
          path = file_fixture(path)
        end

        Rack::Test::UploadedFile.new(path, mime_type, binary)
      end
    end

    include FixtureFile

    def assigns(key = nil)
      raise NoMethodError,
        "assigns has been extracted to a gem. To continue using it,
        add `gem 'rails-controller-testing'` to your Gemfile."
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

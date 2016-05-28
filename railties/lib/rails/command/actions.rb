module Rails
  module Command
    module Actions
      private
        # Change to the application's path if there is no config.ru file in current directory.
        # This allows us to run `rails server` from other directories, but still get
        # the main config.ru and properly set the tmp directory.
        def set_application_directory!
          Dir.chdir(File.expand_path("../../", APP_PATH)) unless File.exist?(File.expand_path("config.ru"))
        end

        def require_application_and_environment!
          require APP_PATH
          Rails.application.require_environment!
        end
    end
  end
end

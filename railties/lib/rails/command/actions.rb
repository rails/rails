module Rails
  module Command
    module Actions
      # Change to the application's path if there is no config.ru file in current directory.
      # This allows us to run `rails server` from other directories, but still get
      # the main config.ru and properly set the tmp directory.
      def set_application_directory!
        Dir.chdir(File.expand_path("../../", APP_PATH)) unless File.exist?(File.expand_path("config.ru"))
      end

      def require_application_and_environment!
        require ENGINE_PATH if defined?(ENGINE_PATH)

        if defined?(APP_PATH)
          require APP_PATH
          Rails.application.require_environment!
        end
      end

      if defined?(ENGINE_PATH)
        def load_tasks
          Rake.application.init("rails")
          Rake.application.load_rakefile
        end

        def load_generators
          engine = ::Rails::Engine.find(ENGINE_ROOT)
          Rails::Generators.namespace = engine.railtie_namespace
          engine.load_generators
        end
      else
        def load_tasks
          Rails.application.load_tasks
        end

        def load_generators
          Rails.application.load_generators
        end
      end
    end
  end
end

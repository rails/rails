# frozen_string_literal: true

module Rails
  module Command
    module Actions
      # Change to the application's path if there is no <tt>config.ru</tt> file in current directory.
      # This allows us to run <tt>rails server</tt> from other directories, but still get
      # the main <tt>config.ru</tt> and properly set the <tt>tmp</tt> directory.
      def set_application_directory!
        Dir.chdir(File.expand_path("../..", APP_PATH)) unless File.exist?(File.expand_path("config.ru"))
      end

      def require_application!
        require ENGINE_PATH if defined?(ENGINE_PATH)
        require APP_PATH if defined?(APP_PATH)
      end

      def boot_application!
        require_application!
        Rails.application.require_environment! if defined?(APP_PATH)
      end

      def load_environment_config!
        require_application!
        # Only run initializers that are in the :all group, which includes the
        # :load_environment_config initializer.
        Rails.application.initialize!(:_) if defined?(APP_PATH)
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

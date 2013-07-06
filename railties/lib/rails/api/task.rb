require 'rdoc/task'

module Rails
  module API
    class Task < RDoc::Task
      RDOC_FILES = {
        'activesupport' => {
          :include => %w(
            README.rdoc
            CHANGELOG.md
            lib/active_support/**/*.rb
          ),
          :exclude => 'lib/active_support/vendor/*'
        },

        'activerecord' => {
          :include => %w(
            README.rdoc
            CHANGELOG.md
            lib/active_record/**/*.rb
          ),
          :exclude => 'lib/active_record/vendor/*'
        },

        'activemodel' => {
          :include => %w(
            README.rdoc
            CHANGELOG.md
            lib/active_model/**/*.rb
          )
        },

        'actionpack' => {
          :include => %w(
            README.rdoc
            CHANGELOG.md
            lib/abstract_controller/**/*.rb
            lib/action_controller/**/*.rb
            lib/action_dispatch/**/*.rb
            lib/action_view/**/*.rb
          ),
          :exclude => 'lib/action_controller/vendor/*'
        },

        'actionmailer' => {
          :include => %w(
            README.rdoc
            CHANGELOG.md
            lib/action_mailer/**/*.rb
          ),
          :exclude => 'lib/action_mailer/vendor/*'
        },

        'railties' => {
          :include => %w(
            README.rdoc
            CHANGELOG.md
            MIT-LICENSE
            lib/**/*.rb
          ),
          :exclude => 'lib/rails/generators/rails/**/templates/**/*.rb'
        }
      }

      def initialize(name)
        super

        # Every time rake runs this task is instantiated as all the rest.
        # Be lazy computing stuff to have as light impact as possible to
        # the rest of tasks.
        before_running_rdoc do
          load_and_configure_sdoc
          configure_rdoc_files
          setup_horo_variables
        end
      end

      # Hack, ignore the desc calls performed by the original initializer.
      def desc(description)
        # no-op
      end

      def load_and_configure_sdoc
        require 'sdoc'

        self.title    = 'Ruby on Rails API'
        self.rdoc_dir = api_dir

        options << '-m'  << api_main
        options << '-e'  << 'UTF-8'

        options << '-f'  << 'sdoc'
        options << '-T'  << 'rails'
      rescue LoadError
        $stderr.puts %(Unable to load SDoc, please add\n\n    gem 'sdoc', require: false\n\nto the Gemfile.)
        exit 1
      end

      def configure_rdoc_files
        rdoc_files.include(api_main)

        RDOC_FILES.each do |component, cfg|
          cdr = component_root_dir(component)

          Array(cfg[:include]).each do |pattern|
            rdoc_files.include("#{cdr}/#{pattern}")
          end

          Array(cfg[:exclude]).each do |pattern|
            rdoc_files.exclude("#{cdr}/#{pattern}")
          end
        end
      end

      def setup_horo_variables
        ENV['HORO_PROJECT_NAME']    = 'Ruby on Rails'
        ENV['HORO_PROJECT_VERSION'] = rails_version
      end

      def api_main
        component_root_dir('railties') + '/RDOC_MAIN.rdoc'
      end
    end

    class RepoTask < Task
      def load_and_configure_sdoc
        super
        options << '-g' # link to GitHub, SDoc flag
      end

      def component_root_dir(component)
        component
      end

      def api_dir
        'doc/rdoc'
      end
    end

    class EdgeTask < RepoTask
      def rails_version
        "master@#{`git rev-parse HEAD`[0, 7]}"
      end
    end

    class StableTask < RepoTask
      def rails_version
        File.read('RAILS_VERSION').strip
      end
    end

    class AppTask < Task
      def component_root_dir(gem_name)
        $:.grep(%r{#{gem_name}[\w.-]*/lib\z}).first[0..-5]
      end

      def api_dir
        'doc/api'
      end

      def rails_version
        Rails::VERSION::STRING
      end
    end
  end
end

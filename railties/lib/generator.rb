require 'fileutils'
require 'active_record/support/inflector'

module Generator
  class GeneratorError < StandardError; end

  class Base
    @@template_root = File.dirname(__FILE__) + '/../generators/templates'
    cattr_accessor :template_root

    attr_reader :rails_root, :class_name, :file_name, :table_name,
                :actions, :options

    def initialize(rails_root, object_name, actions = [], options = {})
      @rails_root = rails_root
      @class_name = Inflector.camelize(object_name)
      @file_name  = Inflector.underscore(@class_name)
      @table_name = Inflector.pluralize(@file_name)
      @actions    = actions
      @options    = options

      # Use local templates if rails_root/generators directory exists.
      local_template_root = File.join(@rails_root, 'generators')
      if File.directory?(local_template_root)
        self.class.template_root = local_template_root
      end
    end

    protected

      # Generate a file in a fresh Rails app from an ERB template.
      # Takes a template path relative to +template_root+, a
      # destination path relative to +rails_root+, evaluates the template,
      # and writes the result to the destination.
      def generate_file(template_file_path, rails_file_path, eval_binding = nil)
        # Determine full paths for source and destination files.
        template_path = File.join(template_root, template_file_path)
        rails_path    = File.join(rails_root, rails_file_path)

        # Create destination directories.
        FileUtils.mkdir_p(File.dirname(rails_path))

        # Render template and write result.
        eval_binding ||= binding
        contents = ERB.new(File.read(template_path), nil, '-').result(eval_binding)
        File.open(rails_path, 'w') { |file| file.write(contents) }
      end
  end

  # Generate controller, helper, functional test, and views.
  class Controller < Base
    def generate
      options[:scaffold] = file_name if options[:scaffold]

      # Controller class.
      generate_file "controller.erb", "app/controllers/#{file_name}_controller.rb"

      # Helper class.
      generate_file "helper.erb", "app/helpers/#{file_name}_helper.rb"

      # Function test.
      generate_file "controller_test.erb", "test/functional/#{file_name}_controller_test.rb"

      # Create the views directory even if there are no actions.
      FileUtils.mkdir_p "app/views/#{file_name}"

      # View template for each action.
      @actions.each do |action|
        generate_file "controller_view.rhtml",
                      "app/views/#{file_name}/#{action}.rhtml",
                      binding
      end
    end
  end

  # Generate model, unit test, and fixtures. 
  class Model < Base
    def generate

      # Model class.
      generate_file "model.erb", "app/models/#{file_name}.rb"

      # Model unit test.
      generate_file "model_test.erb", "test/unit/#{file_name}_test.rb"

      # Test fixtures directory.
      FileUtils.mkdir_p("test/fixtures/#{table_name}")
    end
  end

  # Generate mailer, helper, functional test, and views.
  class Mailer < Base
    def generate

      # Mailer class.
      generate_file "mailer.erb", "app/models/#{file_name}.rb"

      # Mailer unit test.
      generate_file "mailer_test.erb", "test/unit/#{file_name}_test.rb"

      # Test fixtures directory.
      FileUtils.mkdir_p("test/fixtures/#{table_name}")

      # View template and fixture for each action.
      @actions.each do |action|
        generate_file "mailer_action.rhtml",
                      "app/views/#{file_name}/#{action}.rhtml",
                      binding
        generate_file "mailer_fixture.rhtml",
                      "test/fixtures/#{table_name}/#{action}",
                      binding
      end
    end
  end
end

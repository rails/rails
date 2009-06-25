module Rails
  module Generators
    class MailerGenerator < NamedBase
      argument :actions, :type => :array, :default => []

      def check_class_collision
        class_collisions class_name
      end

      def create_mailer_file
        template "mailer.rb", File.join('app/models', class_path, "#{file_name}.rb")
      end

      add_and_invoke_template_engine_option!
      add_and_invoke_test_framework_option!
    end
  end
end

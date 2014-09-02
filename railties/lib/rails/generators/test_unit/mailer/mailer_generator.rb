require 'rails/generators/test_unit'

module TestUnit # :nodoc:
  module Generators # :nodoc:
    class MailerGenerator < Base # :nodoc:
      argument :actions, type: :array, default: [], banner: "method method"

      def check_class_collision
        class_collisions "#{class_name}Test", "#{class_name}Preview"
      end

      def create_test_files
        template "functional_test.rb", File.join('test/mailers', class_path, "#{file_name}_test.rb")
      end

      def create_preview_files
        template "preview.rb", File.join('test/mailers/previews', class_path, "#{file_name}_preview.rb")
      end
    end
  end
end

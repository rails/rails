# frozen_string_literal: true

require "rails/generators/test_unit"

module TestUnit # :nodoc:
  module Generators # :nodoc:
    class MailerGenerator < Base # :nodoc:
      argument :actions, type: :array, default: [], banner: "method method"

      def check_class_collision
        class_collisions "#{class_name}MailerTest", "#{class_name}MailerPreview"
      end

      def create_test_files
        template "functional_test.rb", File.join("test/mailers", class_path, "#{file_name}_mailer_test.rb")
      end

      def create_preview_files
        template "preview.rb", File.join("test/mailers/previews", class_path, "#{file_name}_mailer_preview.rb")
      end

      private
        def file_name
          @_file_name ||= super.sub(/_mailer\z/i, "")
        end
    end
  end
end

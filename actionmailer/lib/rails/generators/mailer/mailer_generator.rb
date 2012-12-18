module Rails
  module Generators
    class MailerGenerator < NamedBase
      source_root File.expand_path("../templates", __FILE__)

      argument :actions, type: :array, default: [], banner: "method method"
      check_class_collision

      def create_mailer_file
        destination = File.join('app/mailers', class_path, "#{file_name}.rb")
        template "mailer.rb", destination
        open_file_in_editor(destination) if options["editor"].present?
      end

      hook_for :template_engine, :test_framework
    end
  end
end

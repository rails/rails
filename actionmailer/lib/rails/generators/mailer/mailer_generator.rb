module Rails
  module Generators
    class MailerGenerator < NamedBase
      source_root File.expand_path("../templates", __FILE__)

      argument :actions, type: :array, default: [], banner: "method method"
      check_class_collision

      def create_mailer_file
        template "mailer.rb", File.join('app/mailers', class_path, "#{file_name}.rb")
        if self.behavior == :invoke
          template "application_mailer.rb", 'app/mailers/application_mailer.rb'
        end
      end

      hook_for :template_engine, :test_framework
    end
  end
end

module Rails
  module Generators
    class MailerGenerator < NamedBase
      source_root File.expand_path("../templates", __FILE__)

      argument :actions, type: :array, default: [], banner: "method method"

      check_class_collision suffix: "Mailer"

      def create_mailer_file
        template "mailer.rb", File.join("app/mailers", class_path, "#{file_name}_mailer.rb")

        in_root do
          if self.behavior == :invoke && !File.exist?(application_mailer_file_name)
            template "application_mailer.rb", application_mailer_file_name
          end
        end
      end

      hook_for :template_engine, :test_framework

      protected
        def file_name
          @_file_name ||= super.gsub(/_mailer/i, "")
        end

      private
        def application_mailer_file_name
          @_application_mailer_file_name ||= if mountable_engine?
            "app/mailers/#{namespaced_path}/application_mailer.rb"
          else
            "app/mailers/application_mailer.rb"
          end
        end
    end
  end
end

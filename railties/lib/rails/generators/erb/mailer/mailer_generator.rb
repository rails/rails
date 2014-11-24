require 'rails/generators/erb/controller/controller_generator'

module Erb # :nodoc:
  module Generators # :nodoc:
    class MailerGenerator < ControllerGenerator # :nodoc:
      def copy_view_files
        view_base_path = File.join("app/views", class_path, file_name)
        empty_directory view_base_path

        layout_base_path = "app/views/layouts"

        actions.each do |action|
          @action = action

          formats.each do |format|
            @view_path = File.join(view_base_path, filename_with_extensions(action, format))
            template filename_with_extensions(:view, format), @view_path

            @layout_path = File.join(layout_base_path, filename_with_extensions("mailer", format))
            template filename_with_extensions(:layout, format), @layout_path
          end
        end

      end

      protected

      def formats
        [:text, :html]
      end
    end
  end
end

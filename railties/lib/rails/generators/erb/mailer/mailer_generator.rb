# frozen_string_literal: true

require "rails/generators/erb"

module Erb # :nodoc:
  module Generators # :nodoc:
    class MailerGenerator < Base # :nodoc:
      argument :actions, type: :array, default: [], banner: "method method"

      def copy_view_files
        view_base_path = File.join("app/views", class_path, file_name + "_mailer")
        empty_directory view_base_path

        if behavior == :invoke
          formats.each do |format|
            layout_path = File.join("app/views/layouts", class_path, filename_with_extensions("mailer", format))
            template filename_with_extensions(:layout, format), layout_path unless File.exist?(layout_path)
          end
        end

        actions.each do |action|
          @action = action

          formats.each do |format|
            @path = File.join(view_base_path, filename_with_extensions(action, format))
            template filename_with_extensions(:view, format), @path
          end
        end
      end

      private

        def formats
          [:text, :html]
        end

        def file_name
          @_file_name ||= super.gsub(/_mailer/i, "")
        end
    end
  end
end

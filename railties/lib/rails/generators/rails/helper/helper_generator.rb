module Rails
  module Generators
    class HelperGenerator < NamedBase # :nodoc:
      check_class_collision suffix: "Helper"

      def create_helper_files
        destination = File.join('app/helpers', class_path, "#{file_name}_helper.rb")
        template 'helper.rb', destination
        open_file_in_editor(destination) if options["editor"].present?
      end

      hook_for :test_framework
    end
  end
end

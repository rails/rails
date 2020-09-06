# frozen_string_literal: true

module Rails
  module Generators
    class HelperGenerator < NamedBase # :nodoc:
      check_class_collision suffix: 'Helper'

      def create_helper_files
        template 'helper.rb', File.join('app/helpers', class_path, "#{file_name}_helper.rb")
      end

      hook_for :test_framework

      private
        def file_name
          @_file_name ||= super.sub(/_helper\z/i, '')
        end
    end
  end
end

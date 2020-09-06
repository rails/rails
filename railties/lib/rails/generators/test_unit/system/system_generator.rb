# frozen_string_literal: true

require 'rails/generators/test_unit'

module TestUnit # :nodoc:
  module Generators # :nodoc:
    class SystemGenerator < Base # :nodoc:
      check_class_collision suffix: 'Test'

      def create_test_files
        if !File.exist?(File.join('test/application_system_test_case.rb'))
          template 'application_system_test_case.rb', File.join('test', 'application_system_test_case.rb')
        end

        template 'system_test.rb', File.join('test/system', class_path, "#{file_name.pluralize}_test.rb")
      end

      private
        def file_name
          @_file_name ||= super.sub(/_test\z/i, '')
        end
    end
  end
end

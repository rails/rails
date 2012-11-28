require 'rails/generators/active_record'

module ActiveRecord
  module Generators # :nodoc:
    class ObserverGenerator < Base # :nodoc:
      check_class_collision :suffix => "Observer"

      def create_observer_file
        template 'observer.rb', File.join('app/models', class_path, "#{file_name}_observer.rb")
      end

      hook_for :test_framework
    end
  end
end

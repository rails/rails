module Rails
  module Generators
    class ValidatorGenerator < NamedBase # :nodoc:
      check_class_collision

      class_option :each, type: :boolean, default: false,
                          desc: "Generate ActiveModel::EachValidator"

      def create_validator_file
        template_name = (options[:each]) ? "each_validator" : "validator"
        template "#{template_name}.rb", File.join('app/validators', class_path, "#{file_name}_validator.rb")
      end

      hook_for :test_framework
    end
  end
end

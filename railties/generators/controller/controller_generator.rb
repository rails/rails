require 'rails_generator'

class ControllerGenerator < Rails::Generator::Base
  attr_reader :actions

  def generate
    @actions = args

    # Controller class, functional test, and helper class.
    template "controller.rb", "app/controllers/#{file_name}_controller.rb"
    template "functional_test.rb", "test/functional/#{file_name}_controller_test.rb"
    template "helper.rb", "app/helpers/#{file_name}_helper.rb"

    # Create the views directory even if there are no actions.
    FileUtils.mkdir_p "app/views/#{file_name}"

    # Create a view for each action.
    actions.each do |action|
      template "view.rhtml", "app/views/#{file_name}/#{action}.rhtml", binding
    end
  end

  def full_class_name
    class_name + "Controller"
  end
end

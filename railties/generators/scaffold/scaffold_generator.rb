require 'rails_generator'

class ScaffoldGenerator < Rails::Generator::Base
  def generate
    # Model.
    generator('model').generate

    # Fixtures.
    template "fixtures.yml", "test/fixtures/#{table_name}.yml"

    # Controller class, functional test, helper, and views.
    template "controller.rb", "app/controllers/#{file_name}_controller.rb"
    template "functional_test.rb", "test/functional/#{file_name}_controller_test.rb"
    template "controller/helper.rb", "app/helpers/#{file_name}_helper.rb"

    # Layout and stylesheet.
    unless File.file?("app/views/layouts/scaffold.rhtml")
      template "layout.rhtml", "app/views/layouts/scaffold.rhtml"
    end
    unless File.file?("public/stylesheets/scaffold.css")
      template "style.css", "public/stylesheets/scaffold.css"
    end

    # Scaffolded views.
    scaffold_views.each do |action|
      template "view_#{action}.rhtml", "app/views/#{file_name}/#{action}.rhtml"
    end

    # Unscaffolded views.
    unscaffolded_actions.each do |action|
      template "controller/view.rhtml",
               "app/views/#{file_name}/#{action}.rhtml",
               binding
    end
  end

  def full_class_name
    class_name + "Controller"
  end

  protected
    def scaffold_views
      %w(list show new edit)
    end

    def scaffold_actions
      scaffold_views + %w(index create update destroy)
    end

    def unscaffolded_actions
      args - scaffold_actions
    end

    def suffix
      "_#{singular_name}" if options[:suffix]
    end
end

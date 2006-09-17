class ScaffoldResourceGenerator < Rails::Generator::NamedBase
  attr_reader   :controller_name,
                :controller_class_path,
                :controller_file_path,
                :controller_class_nesting,
                :controller_class_nesting_depth,
                :controller_class_name,
                :controller_singular_name,
                :controller_plural_name
  alias_method  :controller_file_name,  :controller_singular_name
  alias_method  :controller_table_name, :controller_plural_name

  def initialize(runtime_args, runtime_options = {})
    super

    @controller_name = @name.pluralize

    base_name, @controller_class_path, @controller_file_path, @controller_class_nesting, @controller_class_nesting_depth = extract_modules(@controller_name)
    @controller_class_name_without_nesting, @controller_singular_name, @controller_plural_name = inflect_names(base_name)

    if @controller_class_nesting.empty?
      @controller_class_name = @controller_class_name_without_nesting
    else
      @controller_class_name = "#{@controller_class_nesting}::#{@controller_class_name_without_nesting}"
    end
  end

  def manifest
    recorded_session = record do |m|
      # Check for class naming collisions.
      m.class_collisions controller_class_path,       "#{controller_class_name}Controller",
                                                      "#{controller_class_name}Helper"
      m.class_collisions class_path,                  "#{class_name}"

      # Controller, helper, views, and test directories.
      m.directory File.join('app/models', class_path)
      m.directory File.join('app/controllers', controller_class_path)
      m.directory File.join('app/helpers', controller_class_path)
      m.directory File.join('app/views', controller_class_path, controller_file_name)
      m.directory File.join('test/functional', controller_class_path)
      m.directory File.join('test/unit', class_path)

      scaffold_views.each do |action|
        m.template "view_#{action}.rhtml",
                   File.join('app/views',
                             controller_class_path,
                             controller_file_name,
                             "#{action}.rhtml"),
                   :assigns => { :action => action }
      end

      m.template 'model.rb',
                  File.join('app/models',
                            class_path,
                            "#{file_name}.rb")

      m.template 'controller.rb',
                  File.join('app/controllers',
                            controller_class_path,
                            "#{controller_file_name}_controller.rb")

      m.template 'functional_test.rb',
                  File.join('test/functional',
                            controller_class_path,
                            "#{controller_file_name}_controller_test.rb")

      m.template 'helper.rb',
                  File.join('app/helpers',
                            controller_class_path,
                            "#{controller_file_name}_helper.rb")

      m.template 'unit_test.rb',
                  File.join('test/unit',
                            class_path,
                            "#{file_name}_test.rb")

      m.template 'fixtures.yml',
                  File.join('test/fixtures',
                            "#{table_name}.yml")

      unless options[:skip_migration]
        m.migration_template 'migration.rb', 'db/migrate', :assigns => {
          :migration_name => "Create#{class_name.pluralize.gsub(/::/, '')}"
        }, :migration_file_name => "create_#{file_path.gsub(/\//, '_').pluralize}"
      end

      # View template for each action.
      [:index, :new, :edit, :show].each do |action|
        path = File.join('app/views', class_path, table_name, "#{action}.rhtml")
        m.template 'view.rhtml',
          path,
          :assigns => { :action => action, :path => path }
      end
    end

    puts
    puts ("-" * 70)
    puts "Don't forget the restful route in config/routes.rb"
    puts
    puts "  map.resources :#{controller_file_name}"
    puts
    puts ("-" * 70)
    puts

    recorded_session
  end

  protected
    # Override with your own usage banner.
    def banner
      "Usage: #{$0} scaffold_resources ModelName"
    end

    def scaffold_views
      %w[ index show new edit ]
    end

    def model_name 
      class_name.demodulize
    end
end

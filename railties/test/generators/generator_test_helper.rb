module GeneratorTestHelper
  # Instatiates the Generator
  def build_generator(name,params)
    Rails::Generator::Base.instance(name,params)
  end

  # Runs the create command (like the command line does)
  def run_generator(name,params)
    silence_generator do
      build_generator(name,params).command(:create).invoke!
    end
  end

  # Silences the logger temporarily and returns the output as a String
  def silence_generator
    logger_original=Rails::Generator::Base.logger
    myout=StringIO.new
    Rails::Generator::Base.logger=Rails::Generator::SimpleLogger.new(myout)
    yield if block_given?
    Rails::Generator::Base.logger=logger_original
    myout.string
  end

  # asserts that the given controller was generated.
  # It takes a name or symbol without the <tt>_controller</tt> part and an optional super class.
  # The contents of the class source file is passed to a block.
  def assert_generated_controller_for(name,parent="ApplicationController")
    assert_generated_class "app/controllers/#{name.to_s.underscore}_controller",parent do |body|
      yield body if block_given?
    end
  end

  # asserts that the given model was generated.
  # It takes a name or symbol and an optional super class.
  # the contents of the class source file is passed to a block.
  def assert_generated_model_for(name,parent="ActiveRecord::Base")
    assert_generated_class "app/models/#{name.to_s.underscore}",parent do |body|
      yield body if block_given?
    end
  end

  # asserts that the given helper was generated.
  # It takes a name or symbol without the <tt>_helper</tt> part
  # the contents of the module source file is passed to a block.
  def assert_generated_helper_for(name)
    assert_generated_module "app/helpers/#{name.to_s.underscore}_helper" do |body|
      yield body if block_given?
    end
  end

  # asserts that the given functional test was generated.
  # It takes a name or symbol without the <tt>_controller_test</tt> part and an optional super class.
  # the contents of the class source file is passed to a block.
  def assert_generated_functional_test_for(name,parent="Test::Unit::TestCase")
    assert_generated_class "test/functional/#{name.to_s.underscore}_controller_test",parent do |body|
      yield body if block_given?
    end
  end

  # asserts that the given unit test was generated.
  # It takes a name or symbol without the <tt>_test</tt> part and an optional super class.
  # the contents of the class source file is passed to a block.
  def assert_generated_unit_test_for(name,parent="Test::Unit::TestCase")
    assert_generated_class "test/unit/#{name.to_s.underscore}_test",parent do |body|
      yield body if block_given?
    end
  end

  # asserts that the given file was generated.
  # the contents of the file is passed to a block.
  def assert_generated_file(path)
    assert_file_exists(path)
    File.open("#{RAILS_ROOT}/#{path}") do |f|
      yield f.read if block_given?
    end
  end

  # asserts that the given file exists
  def assert_file_exists(path)
    assert File.exists?("#{RAILS_ROOT}/#{path}"),"The file '#{path}' should exist"
  end

  # asserts that the given class source file was generated.
  # It takes a path without the <tt>.rb</tt> part and an optional super class.
  # the contents of the class source file is passed to a block.
  def assert_generated_class(path,parent=nil)
    path=~/\/?(\d+_)?(\w+)$/
    class_name=$2.camelize
    assert_generated_file("#{path}.rb") do |body|
      assert body=~/class #{class_name}#{parent.nil? ? '':" < #{parent}"}/,"the file '#{path}.rb' should be a class"
      yield body if block_given?
    end
  end

  # asserts that the given module source file was generated.
  # It takes a path without the <tt>.rb</tt> part.
  # the contents of the class source file is passed to a block.
  def assert_generated_module(path)
    path=~/\/?(\w+)$/
    module_name=$1.camelize
    assert_generated_file("#{path}.rb") do |body|
      assert body=~/module #{module_name}/,"the file '#{path}.rb' should be a module"
      yield body if block_given?
    end
  end

  # asserts that the given css stylesheet file was generated.
  # It takes a path without the <tt>.css</tt> part.
  # the contents of the stylesheet source file is passed to a block.
  def assert_generated_stylesheet(path)
    assert_generated_file("public/stylesheets/#{path}.css") do |body|
      yield body if block_given?
    end
  end

  # asserts that the given yaml file was generated.
  # It takes a path without the <tt>.yml</tt> part.
  # the parsed yaml tree is passed to a block.
  def assert_generated_yaml(path)
    assert_generated_file("#{path}.yml") do |body|
      assert yaml=YAML.load(body)
      yield yaml if block_given?
    end
  end

  # asserts that the given fixtures yaml file was generated.
  # It takes a fixture name without the <tt>.yml</tt> part.
  # the parsed yaml tree is passed to a block.
  def assert_generated_fixtures_for(name)
    assert_generated_yaml "test/fixtures/#{name.to_s.underscore}" do |yaml|
      assert_generated_timestamps(yaml)
      yield yaml if block_given?
    end
  end

  # asserts that the given views were generated.
  # It takes a controller name and a list of views (including extensions).
  # The body of each view is passed to a block
  def assert_generated_views_for(name,*actions)
    actions.each do |action|
      assert_generated_file("app/views/#{name.to_s.underscore}/#{action.to_s}") do |body|
        yield body if block_given?
      end
    end
  end

  # asserts that the given migration file was generated.
  # It takes the name of the migration as a parameter.
  # The migration body is passed to a block.
  def assert_generated_migration(name,parent="ActiveRecord::Migration")
    assert_generated_class "db/migrate/001_#{name.to_s.underscore}",parent do |body|
      assert body=~/timestamps/, "should have timestamps defined"
      yield body if block_given?
    end
  end

  # Asserts that the given migration file was not generated.
  # It takes the name of the migration as a parameter.
  def assert_skipped_migration(name)
    migration_file = "#{RAILS_ROOT}/db/migrate/001_#{name.to_s.underscore}.rb"
    assert !File.exists?(migration_file), "should not create migration #{migration_file}"
  end

  # asserts that the given resource was added to the routes.
  def assert_added_route_for(name)
    assert_generated_file("config/routes.rb") do |body|
      assert body=~/map.resources :#{name.to_s.underscore}/,"should add route for :#{name.to_s.underscore}"
    end
  end

  # asserts that the given methods are defined in the body.
  # This does assume standard rails code conventions with regards to the source code.
  # The body of each individual method is passed to a block.
  def assert_has_method(body,*methods)
    methods.each do |name|
      assert body=~/^  def #{name.to_s}\n((\n|   .*\n)*)  end/,"should have method #{name.to_s}"
      yield( name, $1 ) if block_given?
    end
  end

  # asserts that the given column is defined in the migration
  def assert_generated_column(body,name,type)
      assert body=~/t\.#{type.to_s} :#{name.to_s}/, "should have column #{name.to_s} defined"
  end

  private
    # asserts that the default timestamps are created in the fixture
    def assert_generated_timestamps(yaml)
      yaml.values.each do |v|
        ["created_at", "updated_at"].each do |field|
          assert v.keys.include?(field), "should have #{field} field by default"
        end
      end
    end
end

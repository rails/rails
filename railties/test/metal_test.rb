require 'abstract_unit'
require 'initializer'

class MetalTest < Test::Unit::TestCase
  def test_metals_should_return_list_of_found_metal_apps
    use_appdir("singlemetal") do
      assert_equal(["FooMetal"], found_metals_as_string_array)
    end
  end

  def test_metals_should_respect_class_name_conventions
    use_appdir("pluralmetal") do
      assert_equal(["LegacyRoutes"], found_metals_as_string_array)
    end
  end

  def test_metals_should_return_alphabetical_list_of_found_metal_apps
    use_appdir("multiplemetals") do
      assert_equal(["MetalA", "MetalB"], found_metals_as_string_array)
    end
  end

  def test_metals_load_order_should_be_overriden_by_requested_metals
    use_appdir("multiplemetals") do
      Rails::Rack::Metal.requested_metals = ["MetalB", "MetalA"]
      assert_equal(["MetalB", "MetalA"], found_metals_as_string_array)
    end
  end

  def test_metals_not_listed_should_not_load
    use_appdir("multiplemetals") do
      Rails::Rack::Metal.requested_metals = ["MetalB"]
      assert_equal(["MetalB"], found_metals_as_string_array)
    end
  end

  def test_metal_finding_should_work_with_subfolders
    use_appdir("subfolders") do
      assert_equal(["Folder::MetalA", "Folder::MetalB"], found_metals_as_string_array)
    end
  end

  def test_metal_finding_with_requested_metals_should_work_with_subfolders
    use_appdir("subfolders") do
      Rails::Rack::Metal.requested_metals = ["Folder::MetalB"]
      assert_equal(["Folder::MetalB"], found_metals_as_string_array)
    end
  end

  def test_metal_finding_should_work_with_multiple_metal_paths_in_185_and_below
    use_appdir("singlemetal") do
      engine_metal_path = "#{File.dirname(__FILE__)}/fixtures/plugins/engines/engine/app/metal" 
      Rails::Rack::Metal.metal_paths << engine_metal_path
      $LOAD_PATH << engine_metal_path
      assert_equal(["FooMetal", "EngineMetal"], found_metals_as_string_array)
    end
  end
  
  def test_metal_default_pass_through_on_404
    use_appdir("multiplemetals") do
      result = Rails::Rack::Metal.new(app).call({})
      assert_equal 200, result.first
      assert_equal ["Metal B"], result.last
    end
  end
  
  def test_metal_pass_through_on_417
    use_appdir("multiplemetals") do
      Rails::Rack::Metal.pass_through_on = 417
      result = Rails::Rack::Metal.new(app).call({})
      assert_equal 404, result.first
      assert_equal ["Metal A"], result.last
    end
  end
  
  def test_metal_pass_through_on_404_and_200
    use_appdir("multiplemetals") do
      Rails::Rack::Metal.pass_through_on = [404, 200]
      result = Rails::Rack::Metal.new(app).call({})
      assert_equal 402, result.first
      assert_equal ["End of the Line"], result.last
    end
  end

  private
  
  def app
    lambda{[402,{},["End of the Line"]]}
  end

  def use_appdir(root)
    dir = "#{File.dirname(__FILE__)}/fixtures/metal/#{root}"
    Rails::Rack::Metal.metal_paths = ["#{dir}/app/metal"]
    Rails::Rack::Metal.requested_metals = nil
    $LOAD_PATH << "#{dir}/app/metal"
    yield
  end

  def found_metals_as_string_array
    Rails::Rack::Metal.metals.map { |m| m.to_s }
  end
end

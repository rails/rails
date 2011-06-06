require 'isolation/abstract_unit'

class LoadingTest < Test::Unit::TestCase
  include ActiveSupport::Testing::Isolation

  def setup
    build_app
    boot_rails
  end

  def teardown
    teardown_app
  end

  def app
    @app ||= Rails.application
  end

  def test_constants_in_app_are_autoloaded
    app_file "app/models/post.rb", <<-MODEL
      class Post < ActiveRecord::Base
        validates_acceptance_of :title, :accept => "omg"
      end
    MODEL

    require "#{rails_root}/config/environment"
    setup_ar!

    p = Post.create(:title => 'omg')
    assert_equal 1, Post.count
    assert_equal 'omg', p.title
    p = Post.first
    assert_equal 'omg', p.title
  end

  def test_models_without_table_do_not_panic_on_scope_definitions_when_loaded
    app_file "app/models/user.rb", <<-MODEL
      class User < ActiveRecord::Base
        default_scope where(:published => true)
      end
    MODEL

    require "#{rails_root}/config/environment"
    setup_ar!

    User
  end

  test "load config/environments/environment before Bootstrap initializers" do
    app_file "config/environments/development.rb", <<-RUBY
      AppTemplate::Application.configure do
        config.development_environment_loaded = true
      end
    RUBY

    add_to_config <<-RUBY
      config.before_initialize do
        config.loaded = config.development_environment_loaded
      end
    RUBY

    require "#{app_path}/config/environment"
    assert ::AppTemplate::Application.config.loaded
  end

  def test_descendants_are_cleaned_on_each_request_without_cache_classes
    add_to_config <<-RUBY
      config.cache_classes = false
    RUBY

    app_file "app/models/post.rb", <<-MODEL
      class Post < ActiveRecord::Base
      end
    MODEL

    app_file 'config/routes.rb', <<-RUBY
      AppTemplate::Application.routes.draw do
        match '/load',   :to => lambda { |env| [200, {}, Post.all] }
        match '/unload', :to => lambda { |env| [200, {}, []] }
      end
    RUBY

    require 'rack/test'
    extend Rack::Test::Methods

    require "#{rails_root}/config/environment"
    setup_ar!

    assert_equal [], ActiveRecord::Base.descendants
    get "/load"
    assert_equal [Post], ActiveRecord::Base.descendants
    get "/unload"
    assert_equal [], ActiveRecord::Base.descendants
  end

  test "initialize_cant_be_called_twice" do
    require "#{app_path}/config/environment"
    assert_raise(RuntimeError) { ::AppTemplate::Application.initialize! }
  end

  protected

  def setup_ar!
    ActiveRecord::Base.establish_connection(:adapter => "sqlite3", :database => ":memory:")
    ActiveRecord::Migration.verbose = false
    ActiveRecord::Schema.define(:version => 1) do
      create_table :posts do |t|
        t.string :title
      end
    end
  end
end

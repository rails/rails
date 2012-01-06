require 'isolation/abstract_unit'

class LoadingTest < ActiveSupport::TestCase
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

  test "constants in app are autoloaded" do
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

  test "models without table do not panic on scope definitions when loaded" do
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

  test "descendants are cleaned on each request without cache classes" do
    add_to_config <<-RUBY
      config.cache_classes = false
      config.reload_classes_only_on_change = false
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

  test "reload constants on development" do
    add_to_config <<-RUBY
      config.cache_classes = false
    RUBY

    app_file 'config/routes.rb', <<-RUBY
      AppTemplate::Application.routes.draw do
        match '/c', :to => lambda { |env| [200, {"Content-Type" => "text/plain"}, [User.counter.to_s]] }
      end
    RUBY

    app_file "app/models/user.rb", <<-MODEL
      class User
        def self.counter; 1; end
      end
    MODEL

    require 'rack/test'
    extend Rack::Test::Methods

    require "#{rails_root}/config/environment"

    get "/c"
    assert_equal "1", last_response.body

    app_file "app/models/user.rb", <<-MODEL
      class User
        def self.counter; 2; end
      end
    MODEL

    get "/c"
    assert_equal "2", last_response.body
  end

  test "does not reload constants on development if custom file watcher always returns false" do
    add_to_config <<-RUBY
      config.cache_classes = false
      config.file_watcher = Class.new do
        def initialize(*); end
        def updated?; false; end
      end
    RUBY

    app_file 'config/routes.rb', <<-RUBY
      AppTemplate::Application.routes.draw do
        match '/c', :to => lambda { |env| [200, {"Content-Type" => "text/plain"}, [User.counter.to_s]] }
      end
    RUBY

    app_file "app/models/user.rb", <<-MODEL
      class User
        def self.counter; 1; end
      end
    MODEL

    require 'rack/test'
    extend Rack::Test::Methods

    require "#{rails_root}/config/environment"

    get "/c"
    assert_equal "1", last_response.body

    app_file "app/models/user.rb", <<-MODEL
      class User
        def self.counter; 2; end
      end
    MODEL

    get "/c"
    assert_equal "1", last_response.body
  end

  test "added files (like db/schema.rb) also trigger reloading" do
    add_to_config <<-RUBY
      config.cache_classes = false
    RUBY

    app_file 'config/routes.rb', <<-RUBY
      $counter = 0
      AppTemplate::Application.routes.draw do
        match '/c', :to => lambda { |env| User; [200, {"Content-Type" => "text/plain"}, [$counter.to_s]] }
      end
    RUBY

    app_file "app/models/user.rb", <<-MODEL
      class User
        $counter += 1
      end
    MODEL

    require 'rack/test'
    extend Rack::Test::Methods

    require "#{rails_root}/config/environment"

    get "/c"
    assert_equal "1", last_response.body

    app_file "db/schema.rb", ""

    get "/c"
    assert_equal "2", last_response.body
  end

  test "columns migrations also trigger reloading" do
    add_to_config <<-RUBY
      config.cache_classes = false
    RUBY

    app_file 'config/routes.rb', <<-RUBY
      AppTemplate::Application.routes.draw do
        match '/title', :to => lambda { |env| [200, {"Content-Type" => "text/plain"}, [Post.new.title]] }
        match '/body',  :to => lambda { |env| [200, {"Content-Type" => "text/plain"}, [Post.new.body]] }
      end
    RUBY

    app_file "app/models/post.rb", <<-MODEL
      class Post < ActiveRecord::Base
      end
    MODEL

    require 'rack/test'
    extend Rack::Test::Methods

    app_file "db/migrate/1_create_posts.rb", <<-MIGRATION
      class CreatePosts < ActiveRecord::Migration
        def change
          create_table :posts do |t|
            t.string :title, :default => "TITLE"
          end
        end
      end
    MIGRATION

    Dir.chdir(app_path) { `rake db:migrate`}
    require "#{rails_root}/config/environment"

    get "/title"
    assert_equal "TITLE", last_response.body

    app_file "db/migrate/2_add_body_to_posts.rb", <<-MIGRATION
      class AddBodyToPosts < ActiveRecord::Migration
        def change
          add_column :posts, :body, :text, :default => "BODY"
        end
      end
    MIGRATION

    Dir.chdir(app_path) { `rake db:migrate` }

    get "/body"
    assert_equal "BODY", last_response.body
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

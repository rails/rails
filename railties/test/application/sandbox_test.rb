# frozen_string_literal: true

require "isolation/abstract_unit"

class SandboxTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::Isolation

  def setup
    build_app
    app_file "app/models/post.rb", <<-RUBY
      class Post < ActiveRecord::Base
      end
    RUBY
  end

  def teardown
    teardown_app
  end

  test "Rails.sandbox rolls back database changes" do
    output = rails("runner", "-e", "development", <<-RUBY)
      Post.lease_connection.create_table(:posts) { |t| t.string :title }

      initial_count = Post.count

      Rails.sandbox do
        Post.create!(title: "Test")
        puts "inside: \#{Post.count}"
      end

      puts "outside: \#{Post.count}"
      puts "initial: \#{initial_count}"
    RUBY

    assert_includes output, "inside: 1"
    assert_includes output, "outside: 0"
    assert_includes output, "initial: 0"
  end

  test "Rails.sandbox returns block value" do
    output = rails("runner", "-e", "development", <<-RUBY)
      Post.lease_connection.create_table(:posts) { |t| t.string :title }

      result = Rails.sandbox do
        Post.create!(title: "Test")
        Post.count
      end

      puts "result: \#{result}"
      puts "actual: \#{Post.count}"
    RUBY

    assert_includes output, "result: 1"
    assert_includes output, "actual: 0"
  end

  test "Rails.sandbox raises in production" do
    output = rails("runner", "-e", "production", <<-RUBY, allow_failure: true)
      begin
        Rails.sandbox { "test" }
      rescue => e
        puts "error: \#{e.class}"
        puts "message: \#{e.message}"
      end
    RUBY

    assert_includes output, "error:"
    assert_match(/only available in development and test|local/, output)
  end

  test "Rails.sandbox works in test environment" do
    output = rails("runner", "-e", "test", <<-RUBY)
      Post.lease_connection.create_table(:posts) { |t| t.string :title }

      Rails.sandbox do
        Post.create!(title: "Test")
        puts "inside: \#{Post.count}"
      end

      puts "outside: \#{Post.count}"
    RUBY

    assert_includes output, "inside: 1"
    assert_includes output, "outside: 0"
  end

  test "Rails.sandbox handles exceptions inside block and still rolls back" do
    output = rails("runner", "-e", "development", <<-RUBY, allow_failure: true)
      Post.lease_connection.create_table(:posts) { |t| t.string :title }

      begin
        Rails.sandbox do
          Post.create!(title: "Test")
          puts "created: \#{Post.count}"
          raise "intentional error"
        end
      rescue => e
        puts "caught: \#{e.message}"
      end

      puts "final: \#{Post.count}"
    RUBY

    assert_includes output, "created: 1"
    assert_includes output, "caught: intentional error"
    assert_includes output, "final: 0"
  end

  test "Rails.sandbox works with nested transactions" do
    output = rails("runner", "-e", "development", <<-RUBY)
      Post.lease_connection.create_table(:posts) { |t| t.string :title }

      Rails.sandbox do
        Post.create!(title: "First")

        Post.transaction do
          Post.create!(title: "Second")
        end

        puts "inside: \#{Post.count}"
      end

      puts "outside: \#{Post.count}"
    RUBY

    assert_includes output, "inside: 2"
    assert_includes output, "outside: 0"
  end

  test "Rails.sandbox works without any handlers registered" do
    output = rails("runner", "-e", "development", <<-RUBY)
      # Clear ActiveRecord's sandbox handler to simulate no ORM
      ActiveRecord::Railtie.sandbox.clear if defined?(ActiveRecord::Railtie)

      result = Rails.sandbox { 42 }
      puts "result: \#{result}"
    RUBY

    assert_includes output, "result: 42"
  end

  test "Rails.sandbox works with multiple databases" do
    # Use multi-db configuration
    build_app(multi_db: true)

    app_file "app/models/application_record.rb", <<-RUBY
      class ApplicationRecord < ActiveRecord::Base
        primary_abstract_class
      end
    RUBY

    app_file "app/models/post.rb", <<-RUBY
      class Post < ApplicationRecord
      end
    RUBY

    app_file "app/models/animal_record.rb", <<-RUBY
      class AnimalRecord < ApplicationRecord
        self.abstract_class = true
        connects_to database: { writing: :animals }
      end
    RUBY

    app_file "app/models/dog.rb", <<-RUBY
      class Dog < AnimalRecord
      end
    RUBY

    output = rails("runner", "-e", "development", <<-RUBY)
      Post.lease_connection.create_table(:posts) { |t| t.string :title }
      Dog.lease_connection.create_table(:dogs) { |t| t.string :name }

      Rails.sandbox do
        Post.create!(title: "My Post")
        Dog.create!(name: "Fido")
        puts "inside_posts: \#{Post.count}"
        puts "inside_dogs: \#{Dog.count}"
      end

      puts "outside_posts: \#{Post.count}"
      puts "outside_dogs: \#{Dog.count}"
    RUBY

    assert_includes output, "inside_posts: 1"
    assert_includes output, "inside_dogs: 1"
    assert_includes output, "outside_posts: 0"
    assert_includes output, "outside_dogs: 0"
  end

  test "Rails.sandbox with multiple handlers composes them correctly" do
    # Define a custom Railtie in lib/ so it's loaded before app initialization
    app_file "lib/custom_sandbox_railtie.rb", <<-RUBY
      class CustomSandboxRailtie < Rails::Railtie
        sandbox do |app, &block|
          puts "before_custom"
          result = block.call
          puts "after_custom"
          result
        end
      end
    RUBY

    # Require the railtie in application.rb
    add_to_config 'require "custom_sandbox_railtie"'

    output = rails("runner", "-e", "development", <<-RUBY)
      Post.lease_connection.create_table(:posts) { |t| t.string :title }

      result = Rails.sandbox do
        puts "inside_block"
        Post.create!(title: "Test")
        Post.count
      end

      puts "result: \#{result}"
      puts "final: \#{Post.count}"
    RUBY

    assert_includes output, "before_custom"
    assert_includes output, "inside_block"
    assert_includes output, "after_custom"
    assert_includes output, "result: 1"
    assert_includes output, "final: 0"
  end
end

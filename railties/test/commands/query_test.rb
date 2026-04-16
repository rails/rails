# frozen_string_literal: true

require "isolation/abstract_unit"
require "rails/command"

class Rails::Command::QueryTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::Isolation

  setup :build_app
  teardown :teardown_app

  setup do
    app_file "db/migrate/20250101000000_create_posts.rb", <<-RUBY
      class CreatePosts < ActiveRecord::Migration::Current
        def change
          create_table :posts do |t|
            t.string :title
            t.text :body
            t.integer :status, default: 0
            t.timestamps
          end
        end
      end
    RUBY

    app_file "db/migrate/20250101000001_create_comments.rb", <<-RUBY
      class CreateComments < ActiveRecord::Migration::Current
        def change
          create_table :comments do |t|
            t.references :post, null: false
            t.text :body
            t.timestamps
          end
        end
      end
    RUBY

    app_file "app/models/post.rb", <<-RUBY
      class Post < ApplicationRecord
        enum :status, { draft: 0, published: 1 }
        has_many :comments
      end
    RUBY

    app_file "app/models/comment.rb", <<-RUBY
      class Comment < ApplicationRecord
        belongs_to :post
      end
    RUBY

    rails "db:migrate"
  end

  test "executes raw SQL" do
    data = query_json("--sql", "SELECT 1 AS num")

    assert_equal [ "num" ], data["columns"]
    assert_equal [ [ 1 ] ], data["rows"]
  end

  test "executes AR expression returning a relation" do
    data = query_json("Post.all")

    assert_includes data["columns"], "id"
    assert_includes data["columns"], "title"
  end

  test "executes AR expression returning a scalar" do
    data = query_json("Post.count")

    assert_equal [ "result" ], data["columns"]
    assert_kind_of Integer, data.dig("rows", 0, 0)
  end

  test "paginates SQL results" do
    rails "runner", '3.times { |i| Post.create!(title: "Post #{i}") }'

    data = query_json("--sql", "SELECT * FROM posts ORDER BY id", "--per", "2")

    assert_equal 2, data.dig("meta", "row_count")
    assert data.dig("meta", "has_more")
  end

  test "paginates to page 2 with different results" do
    rails "runner", '4.times { |i| Post.create!(title: "Post #{i}") }'

    page1 = query_json("--sql", "SELECT * FROM posts ORDER BY id", "--per", "2", "--page", "1")
    page2 = query_json("--sql", "SELECT * FROM posts ORDER BY id", "--per", "2", "--page", "2")

    assert_not_equal page1["rows"], page2["rows"]
  end

  test "does not double-eval on connection failure" do
    app_file "app/models/counter.rb", <<-RUBY
      class Counter
        FILE = Rails.root.join("tmp/eval_count")
        def self.track
          count = FILE.exist? ? FILE.read.to_i : 0
          FILE.write(count + 1)
          count + 1
        end
      end
    RUBY

    query_error("Counter.track; raise ActiveRecord::ConnectionNotEstablished")

    count = File.read(File.join(app_path, "tmp/eval_count")).to_i
    assert_equal 1, count
  end

  test "prevents writes" do
    output = query_error("--sql", "INSERT INTO posts (title) VALUES ('test')")

    assert_match(/readonly|Write query/i, output)
  end

  test "json format handles nil values" do
    data = query_json("--sql", "SELECT NULL AS val")

    assert_nil data.dig("rows", 0, 0)
  end

  test "schema lists tables" do
    data = query_json("schema")

    assert_includes data["rows"].map(&:first), "posts"
  end

  test "schema shows table detail" do
    data = query_json("schema", "posts")

    assert_equal "posts", data["table"]
    assert_includes data["columns"].map { |col| col["name"] }, "id"
    assert_includes data["columns"].map { |col| col["name"] }, "title"
  end

  test "schema shows enums" do
    data = query_json("schema", "posts")

    assert_equal({ "draft" => 0, "published" => 1 }, data.dig("enums", "status"))
  end

  test "models lists AR models with associations" do
    data = query_json("models")
    post = data.find { |m| m["model"] == "Post" }

    assert_equal "posts", post["table_name"]
    assert_equal "has_many", post["associations"].first["type"]
    assert_equal "comments", post["associations"].first["name"]
  end

  test "schema shows associations" do
    data = query_json("schema", "comments")

    belongs_to = data["associations"].find { |a| a["name"] == "post" }
    assert_equal "belongs_to", belongs_to["type"]
    assert_equal "Post", belongs_to["class_name"]
    assert_equal "post_id", belongs_to["foreign_key"]
  end

  test "executes AR expression returning a hash" do
    data = query_json("Post.column_names.index_with { |c| c.upcase }")

    assert_equal [ "key", "value" ], data["columns"]
    assert data["rows"].any?
  end

  test "executes AR expression returning an array" do
    rails "runner", 'Post.create!(title: "Test")'
    data = query_json("Post.pluck(:title)")

    assert_includes data["columns"], "column_0"
    assert_includes data["rows"].flatten, "Test"
  end

  test "explain with sql flag" do
    data = query_json("explain", "--sql", "SELECT * FROM posts")

    assert data["columns"].any?
    assert data["rows"].any?
  end

  test "per option is clamped to bounds" do
    rails "runner", '3.times { |i| Post.create!(title: "Post #{i}") }'

    data = query_json("--sql", "SELECT * FROM posts ORDER BY id", "--per", "0")
    assert_operator data.dig("meta", "row_count"), :>=, 1

    data = query_json("--sql", "SELECT * FROM posts ORDER BY id", "--per", "99999")
    assert_equal 3, data.dig("meta", "row_count")
  end

  test "explain shows query plan" do
    data = query_json("explain", "Post.where(status: 0)")

    assert data["columns"].any?
    assert data["rows"].any?
  end

  test "handles NameError gracefully" do
    output = query_error("NonexistentModel.all")

    assert_match(/uninitialized constant/, output)
  end

  test "handles SyntaxError gracefully" do
    output = query_error("Post.where(")
    data = JSON.parse(output)

    assert data["error"]
  end

  test "schema errors for nonexistent table" do
    output = query_error("schema", "nonexistent_xyz")

    assert_match(/does not exist/, output)
  end

  test "shows help with no arguments" do
    output = run_query_command("-h")

    assert_match(/query/, output)
  end

  private
    def run_query_command(*args)
      rails "query", *args, allow_failure: true
    end

    def query_json(*args)
      output = run_query_command(*args)
      JSON.parse(output)
    end

    def query_error(*args)
      run_query_command(*args)
    end
end

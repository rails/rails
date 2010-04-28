require 'isolation/abstract_unit'

class PostTest < Test::Unit::TestCase
  include ActiveSupport::Testing::Isolation

  def setup
    build_app
    boot_rails
  end

  def test_reload_should_reload_constants
    app_file "app/models/post.rb", <<-MODEL
      class Post < ActiveRecord::Base
        validates_acceptance_of :title, :accept => "omg"
      end
    MODEL

    require "#{rails_root}/config/environment"
    ActiveRecord::Base.establish_connection(:adapter => "sqlite3", :database => ":memory:")
    ActiveRecord::Migration.verbose = false
    ActiveRecord::Schema.define(:version => 1) do
      create_table :posts do |t|
        t.string :title
      end
    end

    p = Post.create(:title => 'omg')
    assert_equal 1, Post.count
    assert_equal 'omg', p.title
    p = Post.first
    assert_equal 'omg', p.title
  end
end

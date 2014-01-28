require 'cases/helper'
require 'models/post'
require 'models/author'

module ActiveRecord
  class ExtendRelationTest < ActiveRecord::TestCase
    fixtures :posts, :authors

    module MyRelationExtension
      def find(id)
        where(slug: id).first or super
      end
    end

    def setup
      Post.extend_relation(MyRelationExtension)
    end

    def teardown
      Post.relation_extensions = []
    end

    def test_extends_relation
      post = posts(:welcome)
      assert_equal post, Post.find('welcome-to-the-weblog')
    end

    def test_association_extends_relation
      post = posts(:welcome)
      author = authors(:david)
      assert_equal post, author.posts.find('welcome-to-the-weblog')
    end

    def test_chained_association_extends_relation
      post = posts(:welcome)
      author = authors(:david)
      assert_equal post, author.posts.where(type: 'Post').find('welcome-to-the-weblog')
    end

    def test_accepts_block
      Post.extend_relation { def foo; 'foo'; end }
      author = authors(:david)
      assert_equal Post.all.foo, 'foo'
      assert_equal author.posts.foo, 'foo'
    end

    def test_accepts_multiple_modules_and_block
      module1 = Module.new { def foo; 'foo'; end }
      module2 = Module.new { def bar; 'bar'; end }
      Post.extend_relation(module1, module2) { def baz; 'baz'; end }
      assert_equal Post.all.foo, 'foo'
      assert_equal Post.all.bar, 'bar'
      assert_equal Post.all.baz, 'baz'
    end

    def test_relation_extensions
      assert_equal Post.all.relation_extensions, [MyRelationExtension]
      mod = Module.new
      Post.extend_relation(mod)
      assert_equal Post.all.relation_extensions, [MyRelationExtension, mod]
    end
  end
end

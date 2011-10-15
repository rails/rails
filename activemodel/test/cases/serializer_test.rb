require "cases/helper"

class SerializerTest < ActiveModel::TestCase
  class Model
    def initialize(hash={})
      @attributes = hash
    end

    def read_attribute_for_serialization(name)
      @attributes[name]
    end
  end

  class User < Model
    attr_accessor :superuser

    def initialize(hash={})
      super hash.merge(:first_name => "Jose", :last_name => "Valim", :password => "oh noes yugive my password")
    end

    def super_user?
      @superuser
    end
  end

  class Post < Model
    attr_accessor :comments
  end

  class Comment < Model
  end

  class UserSerializer < ActiveModel::Serializer
    attributes :first_name, :last_name
  end

  class User2Serializer < ActiveModel::Serializer
    attributes :first_name, :last_name

    def serializable_hash
      attributes.merge(:ok => true).merge(scope)
    end
  end

  class MyUserSerializer < ActiveModel::Serializer
    attributes :first_name, :last_name

    def serializable_hash
      hash = attributes
      hash = hash.merge(:super_user => true) if my_user.super_user?
      hash
    end
  end

  class CommentSerializer
    def initialize(comment, scope)
      @comment, @scope = comment, scope
    end

    def serializable_hash
      { title: @comment.read_attribute_for_serialization(:title) }
    end

    def as_json
      { comment: serializable_hash }
    end
  end

  class PostSerializer < ActiveModel::Serializer
    attributes :title, :body
    has_many :comments, :serializer => CommentSerializer
  end

  def test_attributes
    user = User.new
    user_serializer = UserSerializer.new(user, nil)

    hash = user_serializer.as_json

    assert_equal({
      :user => { :first_name => "Jose", :last_name => "Valim" }
    }, hash)
  end

  def test_attributes_method
    user = User.new
    user_serializer = User2Serializer.new(user, {})

    hash = user_serializer.as_json

    assert_equal({
      :user2 => { :first_name => "Jose", :last_name => "Valim", :ok => true }
    }, hash)
  end

  def test_serializer_receives_scope
    user = User.new
    user_serializer = User2Serializer.new(user, {:scope => true})

    hash = user_serializer.as_json

    assert_equal({
      :user2 => {
        :first_name => "Jose",
        :last_name => "Valim",
        :ok => true,
        :scope => true
      }
    }, hash)
  end

  def test_pretty_accessors
    user = User.new
    user.superuser = true
    user_serializer = MyUserSerializer.new(user, nil)

    hash = user_serializer.as_json

    assert_equal({
      :my_user => {
        :first_name => "Jose", :last_name => "Valim", :super_user => true
      }
    }, hash)
  end

  def test_has_many
    user = User.new

    post = Post.new(:title => "New Post", :body => "Body of new post", :email => "tenderlove@tenderlove.com")
    comments = [Comment.new(:title => "Comment1"), Comment.new(:title => "Comment2")]
    post.comments = comments

    post_serializer = PostSerializer.new(post, user)

    assert_equal({
      :post => {
        :title => "New Post",
        :body => "Body of new post",
        :comments => [
          { :title => "Comment1" },
          { :title => "Comment2" }
        ]
      }
    }, post_serializer.as_json)
  end

  class Blog < Model
    attr_accessor :author
  end

  class AuthorSerializer < ActiveModel::Serializer
    attributes :first_name, :last_name
  end

  class BlogSerializer < ActiveModel::Serializer
    has_one :author, :serializer => AuthorSerializer
  end

  def test_has_one
    user = User.new
    blog = Blog.new
    blog.author = user

    json = BlogSerializer.new(blog, user).as_json
    assert_equal({
      :blog => {
        :author => {
          :first_name => "Jose",
          :last_name => "Valim"
        }
      }
    }, json)
  end

  def test_implicit_serializer
    author_serializer = Class.new(ActiveModel::Serializer) do
      attributes :first_name
    end

    blog_serializer = Class.new(ActiveModel::Serializer) do
      const_set(:AuthorSerializer, author_serializer)
      has_one :author
    end

    user = User.new
    blog = Blog.new
    blog.author = user

    json = blog_serializer.new(blog, user).as_json
    assert_equal({
      :author => {
        :first_name => "Jose"
      }
    }, json)
  end

  def test_overridden_associations
    author_serializer = Class.new(ActiveModel::Serializer) do
      attributes :first_name
    end

    blog_serializer = Class.new(ActiveModel::Serializer) do
      const_set(:PersonSerializer, author_serializer)

      def person
        object.author
      end

      has_one :person
    end

    user = User.new
    blog = Blog.new
    blog.author = user

    json = blog_serializer.new(blog, user).as_json
    assert_equal({
      :person => {
        :first_name => "Jose"
      }
    }, json)
  end

  def post_serializer(type)
    Class.new(ActiveModel::Serializer) do
      attributes :title, :body
      has_many :comments, :serializer => CommentSerializer

      if type != :super
        define_method :serializable_hash do
          post_hash = attributes
          post_hash.merge!(send(type))
          post_hash
        end
      end
    end
  end

  def test_associations
    post = Post.new(:title => "New Post", :body => "Body of new post", :email => "tenderlove@tenderlove.com")
    comments = [Comment.new(:title => "Comment1"), Comment.new(:title => "Comment2")]
    post.comments = comments

    serializer = post_serializer(:associations).new(post, nil)

    assert_equal({
      :title => "New Post",
      :body => "Body of new post",
      :comments => [
        { :title => "Comment1" },
        { :title => "Comment2" }
      ]
    }, serializer.as_json)
  end

  def test_association_ids
    serializer = post_serializer(:association_ids)

    serializer.class_eval do
      def as_json(*)
        { post: serializable_hash }.merge(associations)
      end
    end

    post = Post.new(:title => "New Post", :body => "Body of new post", :email => "tenderlove@tenderlove.com")
    comments = [Comment.new(:title => "Comment1", :id => 1), Comment.new(:title => "Comment2", :id => 2)]
    post.comments = comments

    serializer = serializer.new(post, nil)

    assert_equal({
      :post => {
        :title => "New Post",
        :body => "Body of new post",
        :comments => [1, 2]
      },
      :comments => [
        { :title => "Comment1" },
        { :title => "Comment2" }
      ]
    }, serializer.as_json)
  end

  def test_associations_with_nil_association
    user = User.new
    blog = Blog.new

    json = BlogSerializer.new(blog, user).as_json
    assert_equal({
      :blog => { :author => nil }
    }, json)

    serializer = Class.new(BlogSerializer) do
      root :blog

      def serializable_hash
        attributes.merge(association_ids)
      end
    end

    json = serializer.new(blog, user).as_json
    assert_equal({ :blog =>  { :author => nil } }, json)
  end

  def test_custom_root
    user = User.new
    blog = Blog.new

    serializer = Class.new(BlogSerializer) do
      root :my_blog
    end

    assert_equal({ :my_blog => { :author => nil } }, serializer.new(blog, user).as_json)
  end

  def test_false_root
    user = User.new
    blog = Blog.new

    serializer = Class.new(BlogSerializer) do
      root false
    end

    assert_equal({ :author => nil }, serializer.new(blog, user).as_json)

    # test inherited false root
    serializer = Class.new(serializer)
    assert_equal({ :author => nil }, serializer.new(blog, user).as_json)
  end

  def test_embed_ids
    serializer = post_serializer(:super)

    serializer.class_eval do
      root :post
      embed :ids
    end

    post = Post.new(:title => "New Post", :body => "Body of new post", :email => "tenderlove@tenderlove.com")
    comments = [Comment.new(:title => "Comment1", :id => 1), Comment.new(:title => "Comment2", :id => 2)]
    post.comments = comments

    serializer = serializer.new(post, nil)

    assert_equal({
      :post => {
        :title => "New Post",
        :body => "Body of new post",
        :comments => [1, 2]
      }
    }, serializer.as_json)
  end

  def test_embed_ids_include_true
    serializer = post_serializer(:super)

    serializer.class_eval do
      root :post
      embed :ids, :include => true
    end

    post = Post.new(:title => "New Post", :body => "Body of new post", :email => "tenderlove@tenderlove.com")
    comments = [Comment.new(:title => "Comment1", :id => 1), Comment.new(:title => "Comment2", :id => 2)]
    post.comments = comments

    serializer = serializer.new(post, nil)

    assert_equal({
      :post => {
        :title => "New Post",
        :body => "Body of new post",
        :comments => [1, 2]
      },
      :comments => [
        { :title => "Comment1" },
        { :title => "Comment2" }
      ]
    }, serializer.as_json)
  end

  def test_embed_objects
    serializer = post_serializer(:super)

    serializer.class_eval do
      root :post
      embed :objects
    end

    post = Post.new(:title => "New Post", :body => "Body of new post", :email => "tenderlove@tenderlove.com")
    comments = [Comment.new(:title => "Comment1", :id => 1), Comment.new(:title => "Comment2", :id => 2)]
    post.comments = comments

    serializer = serializer.new(post, nil)

    assert_equal({
      :post => {
        :title => "New Post",
        :body => "Body of new post",
        :comments => [
          { :title => "Comment1" },
          { :title => "Comment2" }
        ]
      }
    }, serializer.as_json)
  end
end

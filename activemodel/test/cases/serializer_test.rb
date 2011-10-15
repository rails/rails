require "cases/helper"

class SerializerTest < ActiveModel::TestCase
  class Model
    def initialize(hash)
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

    assert_equal({ :first_name => "Jose", :last_name => "Valim" }, hash)
  end

  def test_attributes_method
    user = User.new
    user_serializer = User2Serializer.new(user, {})

    hash = user_serializer.as_json

    assert_equal({ :first_name => "Jose", :last_name => "Valim", :ok => true }, hash)
  end

  def test_serializer_receives_scope
    user = User.new
    user_serializer = User2Serializer.new(user, {:scope => true})

    hash = user_serializer.as_json

    assert_equal({ :first_name => "Jose", :last_name => "Valim", :ok => true, :scope => true }, hash)
  end

  def test_pretty_accessors
    user = User.new
    user.superuser = true
    user_serializer = MyUserSerializer.new(user, nil)

    hash = user_serializer.as_json

    assert_equal({ :first_name => "Jose", :last_name => "Valim", :super_user => true }, hash)
  end

  def test_has_many
    user = User.new

    post = Post.new(:title => "New Post", :body => "Body of new post", :email => "tenderlove@tenderlove.com")
    comments = [Comment.new(:title => "Comment1"), Comment.new(:title => "Comment2")]
    post.comments = comments

    post_serializer = PostSerializer.new(post, user)

    assert_equal({
      :title => "New Post",
      :body => "Body of new post",
      :comments => [
        { :title => "Comment1" },
        { :title => "Comment2" }
      ]
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
    blog = Blog.new(:author => user)
  end
end

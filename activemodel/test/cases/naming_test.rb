# frozen_string_literal: true

require "cases/helper"
require "models/contact"
require "models/sheep"
require "models/track_back"
require "models/blog_post"

class NamingTest < ActiveModel::TestCase
  def setup
    @model_name = ActiveModel::Name.new(Post::TrackBack)
  end

  def test_singular
    assert_equal "post_track_back", @model_name.singular
  end

  def test_plural
    assert_equal "post_track_backs", @model_name.plural
  end

  def test_element
    assert_equal "track_back", @model_name.element
  end

  def test_collection
    assert_equal "post/track_backs", @model_name.collection
  end

  def test_human
    assert_equal "Track back", @model_name.human
  end

  def test_route_key
    assert_equal "post_track_backs", @model_name.route_key
  end

  def test_param_key
    assert_equal "post_track_back", @model_name.param_key
  end

  def test_i18n_key
    assert_equal :"post/track_back", @model_name.i18n_key
  end
end

class NamingWithNamespacedModelInIsolatedNamespaceTest < ActiveModel::TestCase
  def setup
    @model_name = ActiveModel::Name.new(Blog::Post, Blog)
  end

  def test_singular
    assert_equal "blog_post", @model_name.singular
  end

  def test_plural
    assert_equal "blog_posts", @model_name.plural
  end

  def test_element
    assert_equal "post", @model_name.element
  end

  def test_collection
    assert_equal "blog/posts", @model_name.collection
  end

  def test_human
    assert_equal "Post", @model_name.human
  end

  def test_route_key
    assert_equal "posts", @model_name.route_key
  end

  def test_param_key
    assert_equal "post", @model_name.param_key
  end

  def test_i18n_key
    assert_equal :"blog/post", @model_name.i18n_key
  end
end

class NamingWithNamespacedModelInSharedNamespaceTest < ActiveModel::TestCase
  def setup
    @model_name = ActiveModel::Name.new(Blog::Post)
  end

  def test_singular
    assert_equal "blog_post", @model_name.singular
  end

  def test_plural
    assert_equal "blog_posts", @model_name.plural
  end

  def test_element
    assert_equal "post", @model_name.element
  end

  def test_collection
    assert_equal "blog/posts", @model_name.collection
  end

  def test_human
    assert_equal "Post", @model_name.human
  end

  def test_route_key
    assert_equal "blog_posts", @model_name.route_key
  end

  def test_param_key
    assert_equal "blog_post", @model_name.param_key
  end

  def test_i18n_key
    assert_equal :"blog/post", @model_name.i18n_key
  end
end

class NamingWithSuppliedModelNameTest < ActiveModel::TestCase
  def setup
    @model_name = ActiveModel::Name.new(Blog::Post, nil, "Article")
  end

  def test_singular
    assert_equal "article", @model_name.singular
  end

  def test_plural
    assert_equal "articles", @model_name.plural
  end

  def test_element
    assert_equal "article", @model_name.element
  end

  def test_collection
    assert_equal "articles", @model_name.collection
  end

  def test_human
    assert_equal "Article", @model_name.human
  end

  def test_route_key
    assert_equal "articles", @model_name.route_key
  end

  def test_param_key
    assert_equal "article", @model_name.param_key
  end

  def test_i18n_key
    assert_equal :"article", @model_name.i18n_key
  end
end

class NamingUsingRelativeModelNameTest < ActiveModel::TestCase
  def setup
    @model_name = Blog::Post.model_name
  end

  def test_singular
    assert_equal "blog_post", @model_name.singular
  end

  def test_plural
    assert_equal "blog_posts", @model_name.plural
  end

  def test_element
    assert_equal "post", @model_name.element
  end

  def test_collection
    assert_equal "blog/posts", @model_name.collection
  end

  def test_human
    assert_equal "Post", @model_name.human
  end

  def test_route_key
    assert_equal "posts", @model_name.route_key
  end

  def test_param_key
    assert_equal "post", @model_name.param_key
  end

  def test_i18n_key
    assert_equal :"blog/post", @model_name.i18n_key
  end
end

class NamingUsingEnforcedI18nNamingTest < ActiveModel::TestCase
  def setup
    @original_enforce_i18n_naming = ActiveModel::Naming.enforce_i18n_naming
    ActiveModel::Naming.enforce_i18n_naming = true

    @old_load_path, @old_backend = I18n.load_path.dup, I18n.backend
    I18n.load_path.clear
    I18n.backend = I18n::Backend::Simple.new

    @model_name = ActiveModel::Name.new(Contact)
  end

  def teardown
    ActiveModel::Naming.enforce_i18n_naming = @original_enforce_i18n_naming

    I18n.load_path.replace @old_load_path
    I18n.backend = @old_backend
    I18n.backend.reload!
  end

  def test_human_without_enforcing_i18n
    ActiveModel::Naming.enforce_i18n_naming = false
    assert_equal "Contact", @model_name.human
  end

  def test_human_with_default
    assert_equal "<<default>>", @model_name.human(default: "<<default>>")
  end

  def test_human_without_translation
    error = assert_raises(I18n::MissingTranslationData) { @model_name.human }
    assert_equal "translation missing: en.activemodel.models.contact", error.message
  end

  def test_human_with_translation
    I18n.backend.store_translations("en", activemodel: { models: { contact: "<<translation>>" } })
    assert_equal "<<translation>>", @model_name.human
  end
end

class NamingHelpersTest < ActiveModel::TestCase
  def setup
    @klass  = Contact
    @record = @klass.new
    @singular = "contact"
    @plural = "contacts"
    @uncountable = Sheep
    @singular_route_key = "contact"
    @route_key = "contacts"
    @param_key = "contact"
  end

  def test_to_model_called_on_record
    assert_equal "post_named_track_backs", plural(Post::TrackBack.new)
  end

  def test_singular
    assert_equal @singular, singular(@record)
  end

  def test_singular_for_class
    assert_equal @singular, singular(@klass)
  end

  def test_plural
    assert_equal @plural, plural(@record)
  end

  def test_plural_for_class
    assert_equal @plural, plural(@klass)
  end

  def test_route_key
    assert_equal @route_key, route_key(@record)
    assert_equal @singular_route_key, singular_route_key(@record)
  end

  def test_route_key_for_class
    assert_equal @route_key, route_key(@klass)
    assert_equal @singular_route_key, singular_route_key(@klass)
  end

  def test_param_key
    assert_equal @param_key, param_key(@record)
  end

  def test_param_key_for_class
    assert_equal @param_key, param_key(@klass)
  end

  def test_uncountable
    assert uncountable?(@uncountable), "Expected 'sheep' to be uncountable"
    assert_not uncountable?(@klass), "Expected 'contact' to be countable"
  end

  def test_uncountable_route_key
    assert_equal "sheep", singular_route_key(@uncountable)
    assert_equal "sheep_index", route_key(@uncountable)
  end

  private
    def method_missing(method, *args)
      ActiveModel::Naming.send(method, *args)
    end
end

class NameWithAnonymousClassTest < ActiveModel::TestCase
  def test_anonymous_class_without_name_argument
    assert_raises(ArgumentError) do
      ActiveModel::Name.new(Class.new)
    end
  end

  def test_anonymous_class_with_name_argument
    model_name = ActiveModel::Name.new(Class.new, nil, "Anonymous")
    assert_equal "Anonymous", model_name
  end
end

class NamingMethodDelegationTest < ActiveModel::TestCase
  def test_model_name
    assert_equal Blog::Post.model_name, Blog::Post.new.model_name
  end
end

# frozen_string_literal: true

require "cases/helper"
require "models/contact"
require "models/post"
require "models/author"
require "models/tagging"
require "models/tag"
require "models/comment"

module JsonSerializationHelpers
  private
    def set_include_root_in_json(value)
      original_root_in_json = ActiveRecord::Base.include_root_in_json
      ActiveRecord::Base.include_root_in_json = value
      yield
    ensure
      ActiveRecord::Base.include_root_in_json = original_root_in_json
    end
end

class JsonSerializationTest < ActiveRecord::TestCase
  include JsonSerializationHelpers

  class NamespacedContact < Contact
    column :name, "string"
  end

  def setup
    @contact = Contact.new(
      name: "Konata Izumi",
      age: 16,
      avatar: "binarydata",
      created_at: Time.utc(2006, 8, 1),
      awesome: true,
      preferences: { shows: "anime" }
    )
  end

  def test_should_demodulize_root_in_json
    set_include_root_in_json(true) do
      @contact = NamespacedContact.new name: "whatever"
      json = @contact.to_json
      assert_match %r{^\{"namespaced_contact":\{}, json
    end
  end

  def test_should_include_root_in_json
    set_include_root_in_json(true) do
      json = @contact.to_json

      assert_match %r{^\{"contact":\{}, json
      assert_match %r{"name":"Konata Izumi"}, json
      assert_match %r{"age":16}, json
      assert_includes json, %("created_at":#{ActiveSupport::JSON.encode(Time.utc(2006, 8, 1))})
      assert_match %r{"awesome":true}, json
      assert_match %r{"preferences":\{"shows":"anime"\}}, json
    end
  end

  def test_should_encode_all_encodable_attributes
    json = @contact.to_json

    assert_match %r{"name":"Konata Izumi"}, json
    assert_match %r{"age":16}, json
    assert_includes json, %("created_at":#{ActiveSupport::JSON.encode(Time.utc(2006, 8, 1))})
    assert_match %r{"awesome":true}, json
    assert_match %r{"preferences":\{"shows":"anime"\}}, json
  end

  def test_should_allow_attribute_filtering_with_only
    json = @contact.to_json(only: [:name, :age])

    assert_match %r{"name":"Konata Izumi"}, json
    assert_match %r{"age":16}, json
    assert_no_match %r{"awesome":true}, json
    assert_not_includes json, %("created_at":#{ActiveSupport::JSON.encode(Time.utc(2006, 8, 1))})
    assert_no_match %r{"preferences":\{"shows":"anime"\}}, json
  end

  def test_should_allow_attribute_filtering_with_except
    json = @contact.to_json(except: [:name, :age])

    assert_no_match %r{"name":"Konata Izumi"}, json
    assert_no_match %r{"age":16}, json
    assert_match %r{"awesome":true}, json
    assert_includes json, %("created_at":#{ActiveSupport::JSON.encode(Time.utc(2006, 8, 1))})
    assert_match %r{"preferences":\{"shows":"anime"\}}, json
  end

  def test_methods_are_called_on_object
    # Define methods on fixture.
    def @contact.label; "Has cheezburger"; end
    def @contact.favorite_quote; "Constraints are liberating"; end

    # Single method.
    assert_match %r{"label":"Has cheezburger"}, @contact.to_json(only: :name, methods: :label)

    # Both methods.
    methods_json = @contact.to_json(only: :name, methods: [:label, :favorite_quote])
    assert_match %r{"label":"Has cheezburger"}, methods_json
    assert_match %r{"favorite_quote":"Constraints are liberating"}, methods_json
  end

  def test_uses_serializable_hash_with_frozen_hash
    def @contact.serializable_hash(options = nil)
      super({ only: %w(name) }.freeze)
    end

    json = @contact.to_json
    assert_match %r{"name":"Konata Izumi"}, json
    assert_no_match %r{awesome}, json
    assert_no_match %r{age}, json
  end

  def test_uses_serializable_hash_with_only_option
    def @contact.serializable_hash(options = nil)
      super(only: %w(name))
    end

    json = @contact.to_json
    assert_match %r{"name":"Konata Izumi"}, json
    assert_no_match %r{awesome}, json
    assert_no_match %r{age}, json
  end

  def test_uses_serializable_hash_with_except_option
    def @contact.serializable_hash(options = nil)
      super(except: %w(age))
    end

    json = @contact.to_json
    assert_match %r{"name":"Konata Izumi"}, json
    assert_match %r{"awesome":true}, json
    assert_no_match %r{age}, json
  end

  def test_does_not_include_inheritance_column_from_sti
    @contact = ContactSti.new(@contact.attributes)
    assert_equal "ContactSti", @contact.type

    json = @contact.to_json
    assert_match %r{"name":"Konata Izumi"}, json
    assert_no_match %r{type}, json
    assert_no_match %r{ContactSti}, json
  end

  def test_serializable_hash_with_default_except_option_and_excluding_inheritance_column_from_sti
    @contact = ContactSti.new(@contact.attributes)
    assert_equal "ContactSti", @contact.type

    def @contact.serializable_hash(options = {})
      super({ except: %w(age) }.merge!(options))
    end

    json = @contact.to_json
    assert_match %r{"name":"Konata Izumi"}, json
    assert_no_match %r{age}, json
    assert_no_match %r{type}, json
    assert_no_match %r{ContactSti}, json
  end

  def test_serializable_hash_should_not_modify_options_in_argument
    options = { only: :name }.freeze
    assert_nothing_raised { @contact.serializable_hash(options) }
  end
end

class DatabaseConnectedJsonEncodingTest < ActiveRecord::TestCase
  fixtures :authors, :author_addresses, :posts, :comments, :tags, :taggings

  include JsonSerializationHelpers

  def setup
    @david = authors(:david)
    @mary = authors(:mary)
  end

  def test_includes_uses_association_name
    json = @david.to_json(include: :posts)

    assert_match %r{"posts":\[}, json

    assert_match %r{"id":1}, json
    assert_match %r{"name":"David"}, json

    assert_match %r{"author_id":1}, json
    assert_match %r{"title":"Welcome to the weblog"}, json
    assert_match %r{"body":"Such a lovely day"}, json

    assert_match %r{"title":"So I was thinking"}, json
    assert_match %r{"body":"Like I hopefully always am"}, json
  end

  def test_includes_uses_association_name_and_applies_attribute_filters
    json = @david.to_json(include: { posts: { only: :title } })

    assert_match %r{"name":"David"}, json
    assert_match %r{"posts":\[}, json

    assert_match %r{"title":"Welcome to the weblog"}, json
    assert_no_match %r{"body":"Such a lovely day"}, json

    assert_match %r{"title":"So I was thinking"}, json
    assert_no_match %r{"body":"Like I hopefully always am"}, json
  end

  def test_includes_fetches_second_level_associations
    json = @david.to_json(include: { posts: { include: { comments: { only: :body } } } })

    assert_match %r{"name":"David"}, json
    assert_match %r{"posts":\[}, json

    assert_match %r{"comments":\[}, json
    assert_match %r{\{"body":"Thank you again for the welcome"\}}, json
    assert_match %r{\{"body":"Don't think too hard"\}}, json
    assert_no_match %r{"post_id":}, json
  end

  def test_includes_fetches_nth_level_associations
    json = @david.to_json(
      include: {
        posts: {
          include: {
            taggings: {
              include: {
                tag: { only: :name }
              }
            }
          }
        }
    })

    assert_match %r{"name":"David"}, json
    assert_match %r{"posts":\[}, json

    assert_match %r{"taggings":\[}, json
    assert_match %r{"tag":\{"name":"General"\}}, json
  end

  def test_includes_doesnt_merge_opts_from_base
    json = @david.to_json(
      only: :id,
      include: :posts
    )

    assert_match %{"title":"Welcome to the weblog"}, json
  end

  def test_should_not_call_methods_on_associations_that_dont_respond
    def @david.favorite_quote; "Constraints are liberating"; end
    json = @david.to_json(include: :posts, methods: :favorite_quote)

    assert_not_respond_to @david.posts.first, :favorite_quote
    assert_match %r{"favorite_quote":"Constraints are liberating"}, json
    assert_equal 1, %r{"favorite_quote":}.match(json).size
  end

  def test_should_allow_only_option_for_list_of_authors
    set_include_root_in_json(false) do
      authors = [@david, @mary]
      assert_equal %([{"name":"David"},{"name":"Mary"}]), ActiveSupport::JSON.encode(authors, only: :name)
    end
  end

  def test_should_allow_except_option_for_list_of_authors
    set_include_root_in_json(false) do
      authors = [@david, @mary]
      encoded = ActiveSupport::JSON.encode(authors, except: [
        :name, :author_address_id, :author_address_extra_id,
        :organization_id, :owned_essay_id
      ])
      assert_equal %([{"id":1},{"id":2}]), encoded
    end
  end

  def test_should_allow_includes_for_list_of_authors
    authors = [@david, @mary]
    json = ActiveSupport::JSON.encode(authors,
      only: :name,
      include: {
        posts: { only: :id }
      }
    )

    ['"name":"David"', '"posts":[', '{"id":1}', '{"id":2}', '{"id":4}',
     '{"id":5}', '{"id":6}', '"name":"Mary"', '"posts":[', '{"id":7}', '{"id":9}'].each do |fragment|
       assert_includes json, fragment, json
     end
  end

  def test_should_allow_options_for_hash_of_authors
    set_include_root_in_json(true) do
      authors_hash = {
        1 => @david,
        2 => @mary
      }
      assert_equal %({"1":{"author":{"name":"David"}}}), ActiveSupport::JSON.encode(authors_hash, only: [1, :name])
    end
  end

  def test_should_be_able_to_encode_relation
    set_include_root_in_json(true) do
      authors_relation = Author.where(id: [@david.id, @mary.id])

      json = ActiveSupport::JSON.encode authors_relation, only: :name
      assert_equal '[{"author":{"name":"David"}},{"author":{"name":"Mary"}}]', json
    end
  end
end

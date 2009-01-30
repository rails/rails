require "cases/helper"
require 'models/contact'
require 'models/post'
require 'models/author'
require 'models/tagging'
require 'models/tag'
require 'models/comment'

class JsonSerializationTest < ActiveRecord::TestCase
  class NamespacedContact < Contact
    column :name,        :string
  end

  def setup
    @contact = Contact.new(
      :name        => 'Konata Izumi',
      :age         => 16,
      :avatar      => 'binarydata',
      :created_at  => Time.utc(2006, 8, 1),
      :awesome     => true,
      :preferences => { :shows => 'anime' }
    )
  end

  def test_should_demodulize_root_in_json
    NamespacedContact.include_root_in_json = true
    @contact = NamespacedContact.new :name => 'whatever'
    json = @contact.to_json
    assert_match %r{^\{"namespaced_contact": \{}, json
  end

  def test_should_include_root_in_json
    Contact.include_root_in_json = true
    json = @contact.to_json

    assert_match %r{^\{"contact": \{}, json
    assert_match %r{"name": "Konata Izumi"}, json
    assert_match %r{"age": 16}, json
    assert json.include?(%("created_at": #{ActiveSupport::JSON.encode(Time.utc(2006, 8, 1))}))
    assert_match %r{"awesome": true}, json
    assert_match %r{"preferences": \{"shows": "anime"\}}, json
  ensure
    Contact.include_root_in_json = false
  end

  def test_should_encode_all_encodable_attributes
    json = @contact.to_json

    assert_match %r{"name": "Konata Izumi"}, json
    assert_match %r{"age": 16}, json
    assert json.include?(%("created_at": #{ActiveSupport::JSON.encode(Time.utc(2006, 8, 1))}))
    assert_match %r{"awesome": true}, json
    assert_match %r{"preferences": \{"shows": "anime"\}}, json
  end

  def test_should_allow_attribute_filtering_with_only
    json = @contact.to_json(:only => [:name, :age])

    assert_match %r{"name": "Konata Izumi"}, json
    assert_match %r{"age": 16}, json
    assert_no_match %r{"awesome": true}, json
    assert !json.include?(%("created_at": #{ActiveSupport::JSON.encode(Time.utc(2006, 8, 1))}))
    assert_no_match %r{"preferences": \{"shows": "anime"\}}, json
  end

  def test_should_allow_attribute_filtering_with_except
    json = @contact.to_json(:except => [:name, :age])

    assert_no_match %r{"name": "Konata Izumi"}, json
    assert_no_match %r{"age": 16}, json
    assert_match %r{"awesome": true}, json
    assert json.include?(%("created_at": #{ActiveSupport::JSON.encode(Time.utc(2006, 8, 1))}))
    assert_match %r{"preferences": \{"shows": "anime"\}}, json
  end

  def test_methods_are_called_on_object
    # Define methods on fixture.
    def @contact.label; "Has cheezburger"; end
    def @contact.favorite_quote; "Constraints are liberating"; end

    # Single method.
    assert_match %r{"label": "Has cheezburger"}, @contact.to_json(:only => :name, :methods => :label)

    # Both methods.
    methods_json = @contact.to_json(:only => :name, :methods => [:label, :favorite_quote])
    assert_match %r{"label": "Has cheezburger"}, methods_json
    assert_match %r{"favorite_quote": "Constraints are liberating"}, methods_json
  end
end

class DatabaseConnectedJsonEncodingTest < ActiveRecord::TestCase
  fixtures :authors, :posts, :comments, :tags, :taggings

  def setup
    @david = authors(:david)
    @mary = authors(:mary)
  end

  def test_includes_uses_association_name
    json = @david.to_json(:include => :posts)

    assert_match %r{"posts": \[}, json

    assert_match %r{"id": 1}, json
    assert_match %r{"name": "David"}, json

    assert_match %r{"author_id": 1}, json
    assert_match %r{"title": "Welcome to the weblog"}, json
    assert_match %r{"body": "Such a lovely day"}, json

    assert_match %r{"title": "So I was thinking"}, json
    assert_match %r{"body": "Like I hopefully always am"}, json
  end

  def test_includes_uses_association_name_and_applies_attribute_filters
    json = @david.to_json(:include => { :posts => { :only => :title } })

    assert_match %r{"name": "David"}, json
    assert_match %r{"posts": \[}, json

    assert_match %r{"title": "Welcome to the weblog"}, json
    assert_no_match %r{"body": "Such a lovely day"}, json

    assert_match %r{"title": "So I was thinking"}, json
    assert_no_match %r{"body": "Like I hopefully always am"}, json
  end

  def test_includes_fetches_second_level_associations
    json = @david.to_json(:include => { :posts => { :include => { :comments => { :only => :body } } } })

    assert_match %r{"name": "David"}, json
    assert_match %r{"posts": \[}, json

    assert_match %r{"comments": \[}, json
    assert_match %r{\{"body": "Thank you again for the welcome"\}}, json
    assert_match %r{\{"body": "Don't think too hard"\}}, json
    assert_no_match %r{"post_id": }, json
  end

  def test_includes_fetches_nth_level_associations
    json = @david.to_json(
      :include => {
        :posts => {
          :include => {
            :taggings => {
              :include => {
                :tag => { :only => :name }
              }
            }
          }
        }
    })

    assert_match %r{"name": "David"}, json
    assert_match %r{"posts": \[}, json

    assert_match %r{"taggings": \[}, json
    assert_match %r{"tag": \{"name": "General"\}}, json
  end

  def test_should_not_call_methods_on_associations_that_dont_respond
    def @david.favorite_quote; "Constraints are liberating"; end
    json = @david.to_json(:include => :posts, :methods => :favorite_quote)

    assert !@david.posts.first.respond_to?(:favorite_quote)
    assert_match %r{"favorite_quote": "Constraints are liberating"}, json
    assert_equal %r{"favorite_quote": }.match(json).size, 1
  end

  def test_should_allow_only_option_for_list_of_authors
    authors = [@david, @mary]

    assert_equal %([{"name": "David"}, {"name": "Mary"}]), authors.to_json(:only => :name)
  end

  def test_should_allow_except_option_for_list_of_authors
    authors = [@david, @mary]

    assert_equal %([{"id": 1}, {"id": 2}]), authors.to_json(:except => [:name, :author_address_id, :author_address_extra_id])
  end

  def test_should_allow_includes_for_list_of_authors
    authors = [@david, @mary]
    json = authors.to_json(
      :only => :name,
      :include => {
        :posts => { :only => :id }
      }
    )

    ['"name": "David"', '"posts": [', '{"id": 1}', '{"id": 2}', '{"id": 4}',
     '{"id": 5}', '{"id": 6}', '"name": "Mary"', '"posts": [{"id": 7}]'].each do |fragment|
      assert json.include?(fragment), json
     end
  end

  def test_should_allow_options_for_hash_of_authors
    authors_hash = {
      1 => @david,
      2 => @mary
    }

    assert_equal %({"1": {"name": "David"}}), authors_hash.to_json(:only => [1, :name])
  end
end

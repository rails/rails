# frozen_string_literal: true

require "cases/helper"
require "models/topic"
require "models/customer"
require "models/company"
require "models/company_in_module"
require "models/ship"
require "models/pirate"
require "models/price_estimate"
require "models/essay"
require "models/author"
require "models/organization"
require "models/post"
require "models/tagging"
require "models/category"
require "models/book"
require "models/subscriber"
require "models/subscription"
require "models/tag"
require "models/sponsor"
require "models/edge"
require "models/hotel"
require "models/chef"
require "models/department"
require "models/cake_designer"
require "models/drink_designer"
require "models/recipe"
require "models/user_with_invalid_relation"

class ReflectionTest < ActiveRecord::TestCase
  include ActiveRecord::Reflection

  fixtures :topics, :customers, :companies, :subscribers, :price_estimates

  def setup
    @first = Topic.find(1)
  end

  def test_human_name
    assert_equal "Price estimate", PriceEstimate.model_name.human
    assert_equal "Subscriber", Subscriber.model_name.human
  end

  def test_read_attribute_names
    assert_equal(
      %w( id title author_name author_email_address bonus_time written_on last_read content important group approved replies_count unique_replies_count parent_id parent_title type created_at updated_at ).sort,
      @first.attribute_names.sort
    )
  end

  def test_columns
    assert_equal 18, Topic.columns.length
  end

  def test_columns_are_returned_in_the_order_they_were_declared
    column_names = Topic.columns.map(&:name)
    assert_equal %w(id title author_name author_email_address written_on bonus_time last_read content important approved replies_count unique_replies_count parent_id parent_title type group created_at updated_at), column_names
  end

  def test_content_columns
    content_columns        = Topic.content_columns
    content_column_names   = content_columns.map(&:name)
    assert_equal 13, content_columns.length
    assert_equal %w(title author_name author_email_address written_on bonus_time last_read content important group approved parent_title created_at updated_at).sort, content_column_names.sort
  end

  def test_column_string_type_and_limit
    assert_equal :string, @first.column_for_attribute("title").type
    assert_equal :string, @first.column_for_attribute(:title).type
    assert_equal :string, @first.type_for_attribute("title").type
    assert_equal :string, @first.type_for_attribute(:title).type
    assert_equal :string, @first.type_for_attribute("heading").type
    assert_equal :string, @first.type_for_attribute(:heading).type
    assert_equal 250, @first.column_for_attribute("title").limit
  end

  def test_column_null_not_null
    subscriber = Subscriber.first
    assert subscriber.column_for_attribute("name").null
    assert_not subscriber.column_for_attribute("nick").null
  end

  def test_human_name_for_column
    assert_equal "Author name", @first.column_for_attribute("author_name").human_name
  end

  def test_integer_columns
    assert_equal :integer, @first.column_for_attribute("id").type
    assert_equal :integer, @first.column_for_attribute(:id).type
    assert_equal :integer, @first.type_for_attribute("id").type
    assert_equal :integer, @first.type_for_attribute(:id).type
  end

  def test_non_existent_columns_return_null_object
    column = @first.column_for_attribute("attribute_that_doesnt_exist")
    assert_instance_of ActiveRecord::ConnectionAdapters::NullColumn, column
    assert_equal "attribute_that_doesnt_exist", column.name
    assert_nil column.sql_type
    assert_nil column.type

    column = @first.column_for_attribute(:attribute_that_doesnt_exist)
    assert_instance_of ActiveRecord::ConnectionAdapters::NullColumn, column
  end

  def test_non_existent_types_are_identity_types
    type = @first.type_for_attribute("attribute_that_doesnt_exist")
    object = Object.new

    assert_equal object, type.deserialize(object)
    assert_equal object, type.cast(object)
    assert_equal object, type.serialize(object)

    type = @first.type_for_attribute(:attribute_that_doesnt_exist)
    assert_equal object, type.deserialize(object)
    assert_equal object, type.cast(object)
    assert_equal object, type.serialize(object)
  end

  def test_reflection_klass_for_nested_class_name
    reflection = ActiveRecord::Reflection.create(
      :has_many,
      nil,
      nil,
      { class_name: "MyApplication::Business::Company" },
      Customer
    )
    assert_nothing_raised do
      assert_equal MyApplication::Business::Company, reflection.klass
    end
  end

  def test_irregular_reflection_class_name
    ActiveSupport::Inflector.inflections do |inflect|
      inflect.irregular "plural_irregular", "plurales_irregulares"
    end
    reflection = ActiveRecord::Reflection.create(:has_many, "plurales_irregulares", nil, {}, ActiveRecord::Base)
    assert_equal "PluralIrregular", reflection.class_name
  end

  def test_reflection_klass_is_not_ar_subclass
    [:account_invalid,
     :account_class_name,
     :info_invalids,
     :infos_class_name,
     :infos_through_class_name,
    ].each do |rel|
      assert_raise(ArgumentError) do
        UserWithInvalidRelation.reflect_on_association(rel).klass
      end
    end
  end

  def test_aggregation_reflection
    reflection_for_address = AggregateReflection.new(
      :address, nil, { mapping: [ %w(address_street street), %w(address_city city), %w(address_country country) ] }, Customer
    )

    reflection_for_balance = AggregateReflection.new(
      :balance, nil, { class_name: "Money", mapping: %w(balance amount) }, Customer
    )

    reflection_for_gps_location = AggregateReflection.new(
      :gps_location, nil, {}, Customer
    )

    assert_includes Customer.reflect_on_all_aggregations, reflection_for_gps_location
    assert_includes Customer.reflect_on_all_aggregations, reflection_for_balance
    assert_includes Customer.reflect_on_all_aggregations, reflection_for_address

    assert_equal reflection_for_address, Customer.reflect_on_aggregation(:address)

    assert_equal Address, Customer.reflect_on_aggregation(:address).klass

    assert_equal Money, Customer.reflect_on_aggregation(:balance).klass
  end

  def test_reflect_on_all_autosave_associations
    expected = Pirate.reflect_on_all_associations.select { |r| r.options[:autosave] }
    received = Pirate.reflect_on_all_autosave_associations

    assert_not_empty received
    assert_not_equal Pirate.reflect_on_all_associations.length, received.length
    assert_equal expected, received
  end

  def test_has_many_reflection
    reflection_for_clients = ActiveRecord::Reflection.create(:has_many, :clients, nil, { order: "id", dependent: :destroy }, Firm)

    assert_equal reflection_for_clients, Firm.reflect_on_association(:clients)

    assert_equal Client, Firm.reflect_on_association(:clients).klass
    assert_equal "companies", Firm.reflect_on_association(:clients).table_name

    assert_equal Client, Firm.reflect_on_association(:clients_of_firm).klass
    assert_equal "companies", Firm.reflect_on_association(:clients_of_firm).table_name
  end

  def test_has_one_reflection
    reflection_for_account = ActiveRecord::Reflection.create(:has_one, :account, nil, { foreign_key: "firm_id", dependent: :destroy }, Firm)
    assert_equal reflection_for_account, Firm.reflect_on_association(:account)

    assert_equal Account, Firm.reflect_on_association(:account).klass
    assert_equal "accounts", Firm.reflect_on_association(:account).table_name
  end

  def test_belongs_to_inferred_foreign_key_from_assoc_name
    Company.belongs_to :foo
    assert_equal "foo_id", Company.reflect_on_association(:foo).foreign_key
    Company.belongs_to :bar, class_name: "Xyzzy"
    assert_equal "bar_id", Company.reflect_on_association(:bar).foreign_key
    Company.belongs_to :baz, class_name: "Xyzzy", foreign_key: "xyzzy_id"
    assert_equal "xyzzy_id", Company.reflect_on_association(:baz).foreign_key
  end

  def test_association_reflection_in_modules
    ActiveRecord::Base.store_full_sti_class = false

    assert_reflection MyApplication::Business::Firm,
      :clients_of_firm,
      klass: MyApplication::Business::Client,
      class_name: "Client",
      table_name: "companies"

    assert_reflection MyApplication::Billing::Account,
      :firm,
      klass: MyApplication::Business::Firm,
      class_name: "MyApplication::Business::Firm",
      table_name: "companies"

    assert_reflection MyApplication::Billing::Account,
      :qualified_billing_firm,
      klass: MyApplication::Billing::Firm,
      class_name: "MyApplication::Billing::Firm",
      table_name: "companies"

    assert_reflection MyApplication::Billing::Account,
      :unqualified_billing_firm,
      klass: MyApplication::Billing::Firm,
      class_name: "Firm",
      table_name: "companies"

    assert_reflection MyApplication::Billing::Account,
      :nested_qualified_billing_firm,
      klass: MyApplication::Billing::Nested::Firm,
      class_name: "MyApplication::Billing::Nested::Firm",
      table_name: "companies"

    assert_reflection MyApplication::Billing::Account,
      :nested_unqualified_billing_firm,
      klass: MyApplication::Billing::Nested::Firm,
      class_name: "Nested::Firm",
      table_name: "companies"
  ensure
    ActiveRecord::Base.store_full_sti_class = true
  end

  def test_reflection_should_not_raise_error_when_compared_to_other_object
    assert_not_equal Object.new, Firm._reflections["clients"]
  end

  def test_reflections_should_return_keys_as_strings
    assert Category.reflections.keys.all? { |key| key.is_a? String }, "Model.reflections is expected to return string for keys"
  end

  def test_has_and_belongs_to_many_reflection
    assert_equal :has_and_belongs_to_many, Category.reflections["posts"].macro
    assert_equal :posts, Category.reflect_on_all_associations(:has_and_belongs_to_many).first.name
  end

  def test_has_many_through_reflection
    assert_kind_of ThroughReflection, Subscriber.reflect_on_association(:books)
  end

  def test_chain
    expected = [
      Organization.reflect_on_association(:author_essay_categories),
      Author.reflect_on_association(:essays),
      Organization.reflect_on_association(:authors)
    ]
    actual = Organization.reflect_on_association(:author_essay_categories).chain

    assert_equal expected, actual
  end

  def test_scope_chain_does_not_interfere_with_hmt_with_polymorphic_case
    hotel = Hotel.create!
    department = hotel.departments.create!
    department.chefs.create!(employable: CakeDesigner.create!)
    department.chefs.create!(employable: DrinkDesigner.create!)

    assert_equal 1, hotel.cake_designers.size
    assert_equal 1, hotel.cake_designers.count
    assert_equal 1, hotel.drink_designers.size
    assert_equal 1, hotel.drink_designers.count
    assert_equal 2, hotel.chefs.size
    assert_equal 2, hotel.chefs.count
  end

  def test_scope_chain_does_not_interfere_with_hmt_with_polymorphic_case_and_sti
    hotel = Hotel.create!
    hotel.mocktail_designers << MocktailDesigner.create!

    assert_equal 1, hotel.mocktail_designers.size
    assert_equal 1, hotel.mocktail_designers.count
    assert_equal 1, hotel.chef_lists.size
    assert_equal 1, hotel.chef_lists.count

    hotel.mocktail_designers = []

    assert_equal 0, hotel.mocktail_designers.size
    assert_equal 0, hotel.mocktail_designers.count
    assert_equal 0, hotel.chef_lists.size
    assert_equal 0, hotel.chef_lists.count
  end

  def test_scope_chain_of_polymorphic_association_does_not_leak_into_other_hmt_associations
    hotel = Hotel.create!
    department = hotel.departments.create!
    drink = department.chefs.create!(employable: DrinkDesigner.create!)
    Recipe.create!(chef_id: drink.id, hotel_id: hotel.id)

    expected_sql = capture_sql { hotel.recipes.to_a }

    Hotel.reflect_on_association(:recipes).clear_association_scope_cache
    hotel.reload
    hotel.drink_designers.to_a
    loaded_sql = capture_sql { hotel.recipes.to_a }

    assert_equal expected_sql, loaded_sql
  end

  def test_nested?
    assert_not_predicate Author.reflect_on_association(:comments), :nested?
    assert_predicate Author.reflect_on_association(:tags), :nested?

    # Only goes :through once, but the through_reflection is a has_and_belongs_to_many, so this is
    # a nested through association
    assert_predicate Category.reflect_on_association(:post_comments), :nested?
  end

  def test_association_primary_key
    # Normal association
    assert_equal "id",   Author.reflect_on_association(:posts).association_primary_key.to_s
    assert_equal "id",   Author.reflect_on_association(:essay).association_primary_key.to_s
    assert_equal "name", Essay.reflect_on_association(:writer).association_primary_key.to_s

    # Through association (uses the :primary_key option from the source reflection)
    assert_equal "nick", Author.reflect_on_association(:subscribers).association_primary_key.to_s
    assert_equal "name", Author.reflect_on_association(:essay_category).association_primary_key.to_s
    assert_equal "custom_primary_key", Author.reflect_on_association(:tags_with_primary_key).association_primary_key.to_s # nested
  end

  def test_association_primary_key_raises_when_missing_primary_key
    reflection = ActiveRecord::Reflection.create(:has_many, :edge, nil, {}, Author)
    assert_raises(ActiveRecord::UnknownPrimaryKey) { reflection.association_primary_key }

    through = Class.new(ActiveRecord::Reflection::ThroughReflection) {
      define_method(:source_reflection) { reflection }
    }.new(reflection)
    assert_raises(ActiveRecord::UnknownPrimaryKey) { through.association_primary_key }
  end

  def test_active_record_primary_key
    assert_equal "nick", Subscriber.reflect_on_association(:subscriptions).active_record_primary_key.to_s
    assert_equal "name", Author.reflect_on_association(:essay).active_record_primary_key.to_s
  end

  def test_active_record_primary_key_raises_when_missing_primary_key
    reflection = ActiveRecord::Reflection.create(:has_many, :author, nil, {}, Edge)
    assert_raises(ActiveRecord::UnknownPrimaryKey) { reflection.active_record_primary_key }
  end

  def test_type
    assert_equal "taggable_type", Post.reflect_on_association(:taggings).type.to_s
    assert_equal "imageable_class", Post.reflect_on_association(:images).type.to_s
    assert_nil Post.reflect_on_association(:readers).type
  end

  def test_foreign_type
    assert_equal "sponsorable_type", Sponsor.reflect_on_association(:sponsorable).foreign_type.to_s
    assert_equal "sponsorable_type", Sponsor.reflect_on_association(:thing).foreign_type.to_s
    assert_nil Sponsor.reflect_on_association(:sponsor_club).foreign_type
  end

  def test_collection_association
    assert_predicate Pirate.reflect_on_association(:birds), :collection?
    assert_predicate Pirate.reflect_on_association(:parrots), :collection?

    assert_not_predicate Pirate.reflect_on_association(:ship), :collection?
    assert_not_predicate Ship.reflect_on_association(:pirate), :collection?
  end

  def test_default_association_validation
    assert_predicate ActiveRecord::Reflection.create(:has_many, :clients, nil, {}, Firm), :validate?

    assert_not_predicate ActiveRecord::Reflection.create(:has_one, :client, nil, {}, Firm), :validate?
    assert_not_predicate ActiveRecord::Reflection.create(:belongs_to, :client, nil, {}, Firm), :validate?
  end

  def test_always_validate_association_if_explicit
    assert_predicate ActiveRecord::Reflection.create(:has_one, :client, nil, { validate: true }, Firm), :validate?
    assert_predicate ActiveRecord::Reflection.create(:belongs_to, :client, nil, { validate: true }, Firm), :validate?
    assert_predicate ActiveRecord::Reflection.create(:has_many, :clients, nil, { validate: true }, Firm), :validate?
  end

  def test_validate_association_if_autosave
    assert_predicate ActiveRecord::Reflection.create(:has_one, :client, nil, { autosave: true }, Firm), :validate?
    assert_predicate ActiveRecord::Reflection.create(:belongs_to, :client, nil, { autosave: true }, Firm), :validate?
    assert_predicate ActiveRecord::Reflection.create(:has_many, :clients, nil, { autosave: true }, Firm), :validate?
  end

  def test_never_validate_association_if_explicit
    assert_not_predicate ActiveRecord::Reflection.create(:has_one, :client, nil, { autosave: true, validate: false }, Firm), :validate?
    assert_not_predicate ActiveRecord::Reflection.create(:belongs_to, :client, nil, { autosave: true, validate: false }, Firm), :validate?
    assert_not_predicate ActiveRecord::Reflection.create(:has_many, :clients, nil, { autosave: true, validate: false }, Firm), :validate?
  end

  def test_foreign_key
    assert_equal "author_id", Author.reflect_on_association(:posts).foreign_key.to_s
    assert_equal "category_id", Post.reflect_on_association(:categorizations).foreign_key.to_s
  end

  def test_symbol_for_class_name
    assert_equal Client, Firm.reflect_on_association(:unsorted_clients_with_symbol).klass
  end

  def test_class_for_class_name
    error = assert_raises(ArgumentError) do
      ActiveRecord::Reflection.create(:has_many, :clients, nil, { class_name: Client }, Firm)
    end
    assert_equal "A class was passed to `:class_name` but we are expecting a string.", error.message
  end

  def test_class_for_source_type
    error = assert_raises(ArgumentError) do
      ActiveRecord::Reflection.create(:has_many, :tagged_posts, nil, { through: :taggings, source: :taggable, source_type: Post }, Tag)
    end
    assert_equal "A class was passed to `:source_type` but we are expecting a string.", error.message
  end

  def test_join_table
    category = Struct.new(:table_name, :pluralize_table_names).new("categories", true)
    product = Struct.new(:table_name, :pluralize_table_names).new("products", true)

    reflection = ActiveRecord::Reflection.create(:has_many, :categories, nil, {}, product)
    reflection.stub(:klass, category) do
      assert_equal "categories_products", reflection.join_table
    end

    reflection = ActiveRecord::Reflection.create(:has_many, :products, nil, {}, category)
    reflection.stub(:klass, product) do
      assert_equal "categories_products", reflection.join_table
    end
  end

  def test_join_table_with_common_prefix
    category = Struct.new(:table_name, :pluralize_table_names).new("catalog_categories", true)
    product = Struct.new(:table_name, :pluralize_table_names).new("catalog_products", true)

    reflection = ActiveRecord::Reflection.create(:has_many, :categories, nil, {}, product)
    reflection.stub(:klass, category) do
      assert_equal "catalog_categories_products", reflection.join_table
    end

    reflection = ActiveRecord::Reflection.create(:has_many, :products, nil, {}, category)
    reflection.stub(:klass, product) do
      assert_equal "catalog_categories_products", reflection.join_table
    end
  end

  def test_join_table_with_different_prefix
    category = Struct.new(:table_name, :pluralize_table_names).new("catalog_categories", true)
    page = Struct.new(:table_name, :pluralize_table_names).new("content_pages", true)

    reflection = ActiveRecord::Reflection.create(:has_many, :categories, nil, {}, page)
    reflection.stub(:klass, category) do
      assert_equal "catalog_categories_content_pages", reflection.join_table
    end

    reflection = ActiveRecord::Reflection.create(:has_many, :pages, nil, {}, category)
    reflection.stub(:klass, page) do
      assert_equal "catalog_categories_content_pages", reflection.join_table
    end
  end

  def test_join_table_can_be_overridden
    category = Struct.new(:table_name, :pluralize_table_names).new("categories", true)
    product = Struct.new(:table_name, :pluralize_table_names).new("products", true)

    reflection = ActiveRecord::Reflection.create(:has_many, :categories, nil, { join_table: "product_categories" }, product)
    reflection.stub(:klass, category) do
      assert_equal "product_categories", reflection.join_table
    end

    reflection = ActiveRecord::Reflection.create(:has_many, :products, nil, { join_table: "product_categories" }, category)
    reflection.stub(:klass, product) do
      assert_equal "product_categories", reflection.join_table
    end
  end

  def test_includes_accepts_symbols
    hotel = Hotel.create!
    department = hotel.departments.create!
    department.chefs.create!

    assert_nothing_raised do
      assert_equal department.chefs, Hotel.includes([departments: :chefs]).first.chefs
    end
  end

  def test_includes_accepts_strings
    hotel = Hotel.create!
    department = hotel.departments.create!
    department.chefs.create!

    assert_nothing_raised do
      assert_equal department.chefs, Hotel.includes(["departments" => "chefs"]).first.chefs
    end
  end

  def test_reflect_on_association_accepts_symbols
    assert_nothing_raised do
      assert_equal Hotel.reflect_on_association(:departments).name, :departments
    end
  end

  def test_reflect_on_association_accepts_strings
    assert_nothing_raised do
      assert_equal Hotel.reflect_on_association("departments").name, :departments
    end
  end

  private
    def assert_reflection(klass, association, options)
      assert reflection = klass.reflect_on_association(association)
      options.each do |method, value|
        assert_equal(value, reflection.public_send(method))
      end
    end
end

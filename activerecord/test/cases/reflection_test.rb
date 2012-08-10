require "cases/helper"
require 'models/topic'
require 'models/customer'
require 'models/company'
require 'models/company_in_module'
require 'models/subscriber'
require 'models/ship'
require 'models/pirate'
require 'models/price_estimate'
require 'models/essay'
require 'models/author'
require 'models/organization'
require 'models/post'
require 'models/tagging'
require 'models/category'
require 'models/book'
require 'models/subscriber'
require 'models/subscription'
require 'models/tag'
require 'models/sponsor'
require 'models/edge'

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
      %w( id title author_name author_email_address bonus_time written_on last_read content important group approved replies_count parent_id parent_title type created_at updated_at ).sort,
      @first.attribute_names.sort
    )
  end

  def test_columns
    assert_equal 17, Topic.columns.length
  end

  def test_columns_are_returned_in_the_order_they_were_declared
    column_names = Topic.columns.map { |column| column.name }
    assert_equal %w(id title author_name author_email_address written_on bonus_time last_read content important approved replies_count parent_id parent_title type group created_at updated_at), column_names
  end

  def test_content_columns
    content_columns        = Topic.content_columns
    content_column_names   = content_columns.map {|column| column.name}
    assert_equal 13, content_columns.length
    assert_equal %w(title author_name author_email_address written_on bonus_time last_read content important group approved parent_title created_at updated_at).sort, content_column_names.sort
  end

  def test_column_string_type_and_limit
    assert_equal :string, @first.column_for_attribute("title").type
    assert_equal 255, @first.column_for_attribute("title").limit
  end

  def test_column_null_not_null
    subscriber = Subscriber.first
    assert subscriber.column_for_attribute("name").null
    assert !subscriber.column_for_attribute("nick").null
  end

  def test_human_name_for_column
    assert_equal "Author name", @first.column_for_attribute("author_name").human_name
  end

  def test_integer_columns
    assert_equal :integer, @first.column_for_attribute("id").type
  end

  def test_reflection_klass_for_nested_class_name
    reflection = MacroReflection.new(:company, nil, nil, { :class_name => 'MyApplication::Business::Company' }, ActiveRecord::Base)
    assert_nothing_raised do
      assert_equal MyApplication::Business::Company, reflection.klass
    end
  end

  def test_aggregation_reflection
    reflection_for_address = AggregateReflection.new(
      :composed_of, :address, nil, { :mapping => [ %w(address_street street), %w(address_city city), %w(address_country country) ] }, Customer
    )

    reflection_for_balance = AggregateReflection.new(
      :composed_of, :balance, nil, { :class_name => "Money", :mapping => %w(balance amount) }, Customer
    )

    reflection_for_gps_location = AggregateReflection.new(
      :composed_of, :gps_location, nil, { }, Customer
    )

    assert Customer.reflect_on_all_aggregations.include?(reflection_for_gps_location)
    assert Customer.reflect_on_all_aggregations.include?(reflection_for_balance)
    assert Customer.reflect_on_all_aggregations.include?(reflection_for_address)

    assert_equal reflection_for_address, Customer.reflect_on_aggregation(:address)

    assert_equal Address, Customer.reflect_on_aggregation(:address).klass

    assert_equal Money, Customer.reflect_on_aggregation(:balance).klass
  end

  def test_reflect_on_all_autosave_associations
    expected = Pirate.reflect_on_all_associations.select { |r| r.options[:autosave] }
    received = Pirate.reflect_on_all_autosave_associations

    assert !received.empty?
    assert_not_equal Pirate.reflect_on_all_associations.length, received.length
    assert_equal expected, received
  end

  def test_has_many_reflection
    reflection_for_clients = AssociationReflection.new(:has_many, :clients, nil, { :order => "id", :dependent => :destroy }, Firm)

    assert_equal reflection_for_clients, Firm.reflect_on_association(:clients)

    assert_equal Client, Firm.reflect_on_association(:clients).klass
    assert_equal 'companies', Firm.reflect_on_association(:clients).table_name

    assert_equal Client, Firm.reflect_on_association(:clients_of_firm).klass
    assert_equal 'companies', Firm.reflect_on_association(:clients_of_firm).table_name
  end

  def test_has_one_reflection
    reflection_for_account = AssociationReflection.new(:has_one, :account, nil, { :foreign_key => "firm_id", :dependent => :destroy }, Firm)
    assert_equal reflection_for_account, Firm.reflect_on_association(:account)

    assert_equal Account, Firm.reflect_on_association(:account).klass
    assert_equal 'accounts', Firm.reflect_on_association(:account).table_name
  end

  def test_belongs_to_inferred_foreign_key_from_assoc_name
    Company.belongs_to :foo
    assert_equal "foo_id", Company.reflect_on_association(:foo).foreign_key
    Company.belongs_to :bar, :class_name => "Xyzzy"
    assert_equal "bar_id", Company.reflect_on_association(:bar).foreign_key
    Company.belongs_to :baz, :class_name => "Xyzzy", :foreign_key => "xyzzy_id"
    assert_equal "xyzzy_id", Company.reflect_on_association(:baz).foreign_key
  end

  def test_association_reflection_in_modules
    ActiveRecord::Base.store_full_sti_class = false

    assert_reflection MyApplication::Business::Firm,
      :clients_of_firm,
      :klass      => MyApplication::Business::Client,
      :class_name => 'Client',
      :table_name => 'companies'

    assert_reflection MyApplication::Billing::Account,
      :firm,
      :klass      => MyApplication::Business::Firm,
      :class_name => 'MyApplication::Business::Firm',
      :table_name => 'companies'

    assert_reflection MyApplication::Billing::Account,
      :qualified_billing_firm,
      :klass      => MyApplication::Billing::Firm,
      :class_name => 'MyApplication::Billing::Firm',
      :table_name => 'companies'

    assert_reflection MyApplication::Billing::Account,
      :unqualified_billing_firm,
      :klass      => MyApplication::Billing::Firm,
      :class_name => 'Firm',
      :table_name => 'companies'

    assert_reflection MyApplication::Billing::Account,
      :nested_qualified_billing_firm,
      :klass      => MyApplication::Billing::Nested::Firm,
      :class_name => 'MyApplication::Billing::Nested::Firm',
      :table_name => 'companies'

    assert_reflection MyApplication::Billing::Account,
      :nested_unqualified_billing_firm,
      :klass      => MyApplication::Billing::Nested::Firm,
      :class_name => 'Nested::Firm',
      :table_name => 'companies'
  ensure
    ActiveRecord::Base.store_full_sti_class = true
  end

  def test_reflection_of_all_associations
    # FIXME these assertions bust a lot
    assert_equal 39, Firm.reflect_on_all_associations.size
    assert_equal 29, Firm.reflect_on_all_associations(:has_many).size
    assert_equal 10, Firm.reflect_on_all_associations(:has_one).size
    assert_equal 0, Firm.reflect_on_all_associations(:belongs_to).size
  end

  def test_reflection_should_not_raise_error_when_compared_to_other_object
    assert_nothing_raised { Firm.reflections[:clients] == Object.new }
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

  def test_scope_chain
    expected = [
      [Tagging.reflect_on_association(:tag).scope, Post.reflect_on_association(:first_blue_tags).scope],
      [Post.reflect_on_association(:first_taggings).scope],
      [Author.reflect_on_association(:misc_posts).scope]
    ]
    actual = Author.reflect_on_association(:misc_post_first_blue_tags).scope_chain
    assert_equal expected, actual

    expected = [
      [
        Tagging.reflect_on_association(:blue_tag).scope,
        Post.reflect_on_association(:first_blue_tags_2).scope,
        Author.reflect_on_association(:misc_post_first_blue_tags_2).scope
      ],
      [],
      []
    ]
    actual = Author.reflect_on_association(:misc_post_first_blue_tags_2).scope_chain
    assert_equal expected, actual
  end

  def test_nested?
    assert !Author.reflect_on_association(:comments).nested?
    assert Author.reflect_on_association(:tags).nested?

    # Only goes :through once, but the through_reflection is a has_and_belongs_to_many, so this is
    # a nested through association
    assert Category.reflect_on_association(:post_comments).nested?
  end

  def test_association_primary_key
    # Normal association
    assert_equal "id",   Author.reflect_on_association(:posts).association_primary_key.to_s
    assert_equal "name", Author.reflect_on_association(:essay).association_primary_key.to_s
    assert_equal "name", Essay.reflect_on_association(:writer).association_primary_key.to_s

    # Through association (uses the :primary_key option from the source reflection)
    assert_equal "nick", Author.reflect_on_association(:subscribers).association_primary_key.to_s
    assert_equal "name", Author.reflect_on_association(:essay_category).association_primary_key.to_s
    assert_equal "custom_primary_key", Author.reflect_on_association(:tags_with_primary_key).association_primary_key.to_s # nested
  end

  def test_association_primary_key_raises_when_missing_primary_key
    reflection = ActiveRecord::Reflection::AssociationReflection.new(:fuu, :edge, nil, {}, Author)
    assert_raises(ActiveRecord::UnknownPrimaryKey) { reflection.association_primary_key }

    through = ActiveRecord::Reflection::ThroughReflection.new(:fuu, :edge, nil, {}, Author)
    through.stubs(:source_reflection).returns(stub_everything(:options => {}, :class_name => 'Edge'))
    assert_raises(ActiveRecord::UnknownPrimaryKey) { through.association_primary_key }
  end

  def test_active_record_primary_key
    assert_equal "nick", Subscriber.reflect_on_association(:subscriptions).active_record_primary_key.to_s
    assert_equal "name", Author.reflect_on_association(:essay).active_record_primary_key.to_s
  end

  def test_active_record_primary_key_raises_when_missing_primary_key
    reflection = ActiveRecord::Reflection::AssociationReflection.new(:fuu, :author, nil, {}, Edge)
    assert_raises(ActiveRecord::UnknownPrimaryKey) { reflection.active_record_primary_key }
  end

  def test_foreign_type
    assert_equal "sponsorable_type", Sponsor.reflect_on_association(:sponsorable).foreign_type.to_s
    assert_equal "sponsorable_type", Sponsor.reflect_on_association(:thing).foreign_type.to_s
  end

  def test_collection_association
    assert Pirate.reflect_on_association(:birds).collection?
    assert Pirate.reflect_on_association(:parrots).collection?

    assert !Pirate.reflect_on_association(:ship).collection?
    assert !Ship.reflect_on_association(:pirate).collection?
  end

  def test_default_association_validation
    assert AssociationReflection.new(:has_many, :clients, nil, {}, Firm).validate?

    assert !AssociationReflection.new(:has_one, :client, nil, {}, Firm).validate?
    assert !AssociationReflection.new(:belongs_to, :client, nil, {}, Firm).validate?
    assert !AssociationReflection.new(:has_and_belongs_to_many, :clients, nil, {}, Firm).validate?
  end

  def test_always_validate_association_if_explicit
    assert AssociationReflection.new(:has_one, :client, nil, { :validate => true }, Firm).validate?
    assert AssociationReflection.new(:belongs_to, :client, nil, { :validate => true }, Firm).validate?
    assert AssociationReflection.new(:has_many, :clients, nil, { :validate => true }, Firm).validate?
    assert AssociationReflection.new(:has_and_belongs_to_many, :clients, nil, { :validate => true }, Firm).validate?
  end

  def test_validate_association_if_autosave
    assert AssociationReflection.new(:has_one, :client, nil, { :autosave => true }, Firm).validate?
    assert AssociationReflection.new(:belongs_to, :client, nil, { :autosave => true }, Firm).validate?
    assert AssociationReflection.new(:has_many, :clients, nil, { :autosave => true }, Firm).validate?
    assert AssociationReflection.new(:has_and_belongs_to_many, :clients, nil, { :autosave => true }, Firm).validate?
  end

  def test_never_validate_association_if_explicit
    assert !AssociationReflection.new(:has_one, :client, nil, { :autosave => true, :validate => false }, Firm).validate?
    assert !AssociationReflection.new(:belongs_to, :client, nil, { :autosave => true, :validate => false }, Firm).validate?
    assert !AssociationReflection.new(:has_many, :clients, nil, { :autosave => true, :validate => false }, Firm).validate?
    assert !AssociationReflection.new(:has_and_belongs_to_many, :clients, nil, { :autosave => true, :validate => false }, Firm).validate?
  end

  def test_foreign_key
    assert_equal "author_id", Author.reflect_on_association(:posts).foreign_key.to_s
    assert_equal "category_id", Post.reflect_on_association(:categorizations).foreign_key.to_s
  end

  def test_through_reflection_scope_chain_does_not_modify_other_reflections
    orig_conds = Post.reflect_on_association(:first_blue_tags_2).scope_chain.inspect
    Author.reflect_on_association(:misc_post_first_blue_tags_2).scope_chain
    assert_equal orig_conds, Post.reflect_on_association(:first_blue_tags_2).scope_chain.inspect
  end

  def test_symbol_for_class_name
    assert_equal Client, Firm.reflect_on_association(:unsorted_clients_with_symbol).klass
  end

  def test_join_table
    category = Struct.new(:table_name, :pluralize_table_names).new('categories', true)
    product = Struct.new(:table_name, :pluralize_table_names).new('products', true)

    reflection = AssociationReflection.new(:has_and_belongs_to_many, :categories, nil, {}, product)
    reflection.stubs(:klass).returns(category)
    assert_equal 'categories_products', reflection.join_table

    reflection = AssociationReflection.new(:has_and_belongs_to_many, :products, nil, {}, category)
    reflection.stubs(:klass).returns(product)
    assert_equal 'categories_products', reflection.join_table
  end

  def test_join_table_with_common_prefix
    category = Struct.new(:table_name, :pluralize_table_names).new('catalog_categories', true)
    product = Struct.new(:table_name, :pluralize_table_names).new('catalog_products', true)

    reflection = AssociationReflection.new(:has_and_belongs_to_many, :categories, nil, {}, product)
    reflection.stubs(:klass).returns(category)
    assert_equal 'catalog_categories_products', reflection.join_table

    reflection = AssociationReflection.new(:has_and_belongs_to_many, :products, nil, {}, category)
    reflection.stubs(:klass).returns(product)
    assert_equal 'catalog_categories_products', reflection.join_table
  end

  def test_join_table_with_different_prefix
    category = Struct.new(:table_name, :pluralize_table_names).new('catalog_categories', true)
    page = Struct.new(:table_name, :pluralize_table_names).new('content_pages', true)

    reflection = AssociationReflection.new(:has_and_belongs_to_many, :categories, nil, {}, page)
    reflection.stubs(:klass).returns(category)
    assert_equal 'catalog_categories_content_pages', reflection.join_table

    reflection = AssociationReflection.new(:has_and_belongs_to_many, :pages, nil, {}, category)
    reflection.stubs(:klass).returns(page)
    assert_equal 'catalog_categories_content_pages', reflection.join_table
  end

  def test_join_table_can_be_overridden
    category = Struct.new(:table_name, :pluralize_table_names).new('categories', true)
    product = Struct.new(:table_name, :pluralize_table_names).new('products', true)

    reflection = AssociationReflection.new(:has_and_belongs_to_many, :categories, nil, { :join_table => 'product_categories' }, product)
    reflection.stubs(:klass).returns(category)
    assert_equal 'product_categories', reflection.join_table

    reflection = AssociationReflection.new(:has_and_belongs_to_many, :products, nil, { :join_table => 'product_categories' }, category)
    reflection.stubs(:klass).returns(product)
    assert_equal 'product_categories', reflection.join_table
  end

  private
    def assert_reflection(klass, association, options)
      assert reflection = klass.reflect_on_association(association)
      options.each do |method, value|
        assert_equal(value, reflection.send(method))
      end
    end
end

require 'abstract_unit'
require 'fixtures/topic'
require 'fixtures/customer'
require 'fixtures/company'
require 'fixtures/company_in_module'

class ReflectionTest < Test::Unit::TestCase
  fixtures :topics, :customers, :companies

  def setup
    @first = Topic.find(1)
  end

  def test_read_attribute_names
    assert_equal(
      %w( id title author_name author_email_address bonus_time written_on last_read content approved replies_count parent_id type ).sort,
      @first.attribute_names
    )
  end

  def test_columns
    assert_equal 12, Topic.columns.length
  end

  def test_columns_are_returned_in_the_order_they_were_declared
    column_names = Topic.columns.map { |column| column.name }
    assert_equal %w(id title author_name author_email_address written_on bonus_time last_read content approved replies_count parent_id type), column_names
  end

  def test_content_columns
    content_columns        = Topic.content_columns
    content_column_names   = content_columns.map {|column| column.name}
    assert_equal 8, content_columns.length
    assert_equal %w(title author_name author_email_address written_on bonus_time last_read content approved).sort, content_column_names.sort
  end

  def test_column_string_type_and_limit
    assert_equal :string, @first.column_for_attribute("title").type
    assert_equal 255, @first.column_for_attribute("title").limit
  end

  def test_human_name_for_column
    assert_equal "Author name", @first.column_for_attribute("author_name").human_name
  end

  def test_integer_columns
    assert_equal :integer, @first.column_for_attribute("id").type
  end

  def test_aggregation_reflection
    reflection_for_address = ActiveRecord::Reflection::AggregateReflection.new(
      :composed_of, :address, { :mapping => [ %w(address_street street), %w(address_city city), %w(address_country country) ] }, Customer
    )

    reflection_for_balance = ActiveRecord::Reflection::AggregateReflection.new(
      :composed_of, :balance, { :class_name => "Money", :mapping => %w(balance amount) }, Customer
    )

    reflection_for_gps_location = ActiveRecord::Reflection::AggregateReflection.new(
      :composed_of, :gps_location, { }, Customer
    )

    assert_equal(
      [ reflection_for_address, reflection_for_balance, reflection_for_gps_location ],
      Customer.reflect_on_all_aggregations
    )

    assert_equal reflection_for_address, Customer.reflect_on_aggregation(:address)

    assert_equal Address, Customer.reflect_on_aggregation(:address).klass
  end

  def test_has_many_reflection
    reflection_for_clients = ActiveRecord::Reflection::AssociationReflection.new(:has_many, :clients, { :order => "id", :dependent => true }, Firm)

    assert_equal reflection_for_clients, Firm.reflect_on_association(:clients)

    assert_equal Client, Firm.reflect_on_association(:clients).klass
    assert_equal 'companies', Firm.reflect_on_association(:clients).table_name

    assert_equal Client, Firm.reflect_on_association(:clients_of_firm).klass
    assert_equal 'companies', Firm.reflect_on_association(:clients_of_firm).table_name
  end

  def test_has_one_reflection
    reflection_for_account = ActiveRecord::Reflection::AssociationReflection.new(:has_one, :account, { :foreign_key => "firm_id", :dependent => true }, Firm)
    assert_equal reflection_for_account, Firm.reflect_on_association(:account)

    assert_equal Account, Firm.reflect_on_association(:account).klass
    assert_equal 'accounts', Firm.reflect_on_association(:account).table_name
  end

  def test_association_reflection_in_modules
    assert_equal MyApplication::Business::Client, MyApplication::Business::Firm.reflect_on_association(:clients_of_firm).klass
    assert_equal MyApplication::Business::Firm, MyApplication::Billing::Account.reflect_on_association(:firm).klass
  end
end

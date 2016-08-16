require "cases/helper"
require "models/company_in_module"
require "models/shop"
require "models/developer"
require "models/computer"

class ModulesTest < ActiveRecord::TestCase
  fixtures :accounts, :companies, :projects, :developers, :collections, :products, :variants

  def setup
    # need to make sure Object::Firm and Object::Client are not defined,
    # so that constantize will not be able to cheat when having to load namespaced classes
    @undefined_consts = {}

    [:Firm, :Client].each do |const|
      @undefined_consts.merge! const => Object.send(:remove_const, const) if Object.const_defined?(const)
    end

    ActiveRecord::Base.store_full_sti_class = false
  end

  teardown do
    # reinstate the constants that we undefined in the setup
    @undefined_consts.each do |constant, value|
      Object.send :const_set, constant, value unless value.nil?
    end

    ActiveRecord::Base.store_full_sti_class = true
  end

  def test_module_spanning_associations
    firm = MyApplication::Business::Firm.first
    assert !firm.clients.empty?, "Firm should have clients"
    assert_nil firm.class.table_name.match("::"), "Firm shouldn't have the module appear in its table name"
  end

  def test_module_spanning_has_and_belongs_to_many_associations
    project = MyApplication::Business::Project.first
    project.developers << MyApplication::Business::Developer.create("name" => "John")
    assert_equal "John", project.developers.last.name
  end

  def test_associations_spanning_cross_modules
    account = MyApplication::Billing::Account.all.merge!(order: "id").first
    assert_kind_of MyApplication::Business::Firm, account.firm
    assert_kind_of MyApplication::Billing::Firm, account.qualified_billing_firm
    assert_kind_of MyApplication::Billing::Firm, account.unqualified_billing_firm
    assert_kind_of MyApplication::Billing::Nested::Firm, account.nested_qualified_billing_firm
    assert_kind_of MyApplication::Billing::Nested::Firm, account.nested_unqualified_billing_firm
  end

  def test_find_account_and_include_company
    account = MyApplication::Billing::Account.all.merge!(includes: :firm).find(1)
    assert_kind_of MyApplication::Business::Firm, account.firm
  end

  def test_table_name
    assert_equal "accounts", MyApplication::Billing::Account.table_name, "table_name for ActiveRecord model in module"
    assert_equal "companies", MyApplication::Business::Client.table_name, "table_name for ActiveRecord model subclass"
    assert_equal "company_contacts", MyApplication::Business::Client::Contact.table_name, "table_name for ActiveRecord model enclosed by another ActiveRecord model"
  end

  def test_assign_ids
    firm = MyApplication::Business::Firm.first

    assert_nothing_raised do
      firm.client_ids = [MyApplication::Business::Client.first.id]
    end
  end

  # An eager loading condition to force the eager loading model into the old join model.
  def test_eager_loading_in_modules
    clients = []

    assert_nothing_raised do
      clients << MyApplication::Business::Client.references(:accounts).merge!(includes: { firm: :account }, where: "accounts.id IS NOT NULL").find(3)
      clients << MyApplication::Business::Client.includes(firm: :account).find(3)
    end

    clients.each do |client|
      assert_no_queries do
        assert_not_nil(client.firm.account)
      end
    end
  end

  def test_module_table_name_prefix
    assert_equal "prefixed_companies", MyApplication::Business::Prefixed::Company.table_name, "inferred table_name for ActiveRecord model in module with table_name_prefix"
    assert_equal "prefixed_companies", MyApplication::Business::Prefixed::Nested::Company.table_name, "table_name for ActiveRecord model in nested module with a parent table_name_prefix"
    assert_equal "companies", MyApplication::Business::Prefixed::Firm.table_name, "explicit table_name for ActiveRecord model in module with table_name_prefix should not be prefixed"
  end

  def test_module_table_name_prefix_with_global_prefix
    classes = [ MyApplication::Business::Company,
                MyApplication::Business::Firm,
                MyApplication::Business::Client,
                MyApplication::Business::Client::Contact,
                MyApplication::Business::Developer,
                MyApplication::Business::Project,
                MyApplication::Business::Prefixed::Company,
                MyApplication::Business::Prefixed::Nested::Company,
                MyApplication::Billing::Account ]

    ActiveRecord::Base.table_name_prefix = "global_"
    classes.each(&:reset_table_name)
    assert_equal "global_companies", MyApplication::Business::Company.table_name, "inferred table_name for ActiveRecord model in module without table_name_prefix"
    assert_equal "prefixed_companies", MyApplication::Business::Prefixed::Company.table_name, "inferred table_name for ActiveRecord model in module with table_name_prefix"
    assert_equal "prefixed_companies", MyApplication::Business::Prefixed::Nested::Company.table_name, "table_name for ActiveRecord model in nested module with a parent table_name_prefix"
    assert_equal "companies", MyApplication::Business::Prefixed::Firm.table_name, "explicit table_name for ActiveRecord model in module with table_name_prefix should not be prefixed"
  ensure
    ActiveRecord::Base.table_name_prefix = ""
    classes.each(&:reset_table_name)
  end

  def test_module_table_name_suffix
    assert_equal "companies_suffixed", MyApplication::Business::Suffixed::Company.table_name, "inferred table_name for ActiveRecord model in module with table_name_suffix"
    assert_equal "companies_suffixed", MyApplication::Business::Suffixed::Nested::Company.table_name, "table_name for ActiveRecord model in nested module with a parent table_name_suffix"
    assert_equal "companies", MyApplication::Business::Suffixed::Firm.table_name, "explicit table_name for ActiveRecord model in module with table_name_suffix should not be suffixed"
  end

  def test_module_table_name_suffix_with_global_suffix
    classes = [ MyApplication::Business::Company,
                MyApplication::Business::Firm,
                MyApplication::Business::Client,
                MyApplication::Business::Client::Contact,
                MyApplication::Business::Developer,
                MyApplication::Business::Project,
                MyApplication::Business::Suffixed::Company,
                MyApplication::Business::Suffixed::Nested::Company,
                MyApplication::Billing::Account ]

    ActiveRecord::Base.table_name_suffix = "_global"
    classes.each(&:reset_table_name)
    assert_equal "companies_global", MyApplication::Business::Company.table_name, "inferred table_name for ActiveRecord model in module without table_name_suffix"
    assert_equal "companies_suffixed", MyApplication::Business::Suffixed::Company.table_name, "inferred table_name for ActiveRecord model in module with table_name_suffix"
    assert_equal "companies_suffixed", MyApplication::Business::Suffixed::Nested::Company.table_name, "table_name for ActiveRecord model in nested module with a parent table_name_suffix"
    assert_equal "companies", MyApplication::Business::Suffixed::Firm.table_name, "explicit table_name for ActiveRecord model in module with table_name_suffix should not be suffixed"
  ensure
    ActiveRecord::Base.table_name_suffix = ""
    classes.each(&:reset_table_name)
  end

  def test_compute_type_can_infer_class_name_of_sibling_inside_module
    old = ActiveRecord::Base.store_full_sti_class
    ActiveRecord::Base.store_full_sti_class = true
    assert_equal MyApplication::Business::Firm, MyApplication::Business::Client.send(:compute_type, "Firm")
  ensure
    ActiveRecord::Base.store_full_sti_class = old
  end

  def test_nested_models_should_not_raise_exception_when_using_delete_all_dependency_on_association
    old = ActiveRecord::Base.store_full_sti_class
    ActiveRecord::Base.store_full_sti_class = true

    collection = Shop::Collection.first
    assert !collection.products.empty?, "Collection should have products"
    assert_nothing_raised { collection.destroy }
  ensure
    ActiveRecord::Base.store_full_sti_class = old
  end

  def test_nested_models_should_not_raise_exception_when_using_nullify_dependency_on_association
    old = ActiveRecord::Base.store_full_sti_class
    ActiveRecord::Base.store_full_sti_class = true

    product = Shop::Product.first
    assert !product.variants.empty?, "Product should have variants"
    assert_nothing_raised { product.destroy }
  ensure
    ActiveRecord::Base.store_full_sti_class = old
  end
end

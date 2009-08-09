require "cases/helper"
require 'models/company_in_module'

class ModulesTest < ActiveRecord::TestCase
  fixtures :accounts, :companies, :projects, :developers

  def test_module_spanning_associations
    firm = MyApplication::Business::Firm.find(:first)
    assert !firm.clients.empty?, "Firm should have clients"
    assert_nil firm.class.table_name.match('::'), "Firm shouldn't have the module appear in its table name"
  end

  def test_module_spanning_has_and_belongs_to_many_associations
    project = MyApplication::Business::Project.find(:first)
    project.developers << MyApplication::Business::Developer.create("name" => "John")
    assert "John", project.developers.last.name
  end

  def test_associations_spanning_cross_modules
    account = MyApplication::Billing::Account.find(:first, :order => 'id')
    assert_kind_of MyApplication::Business::Firm, account.firm
    assert_kind_of MyApplication::Billing::Firm, account.qualified_billing_firm
    assert_kind_of MyApplication::Billing::Firm, account.unqualified_billing_firm
    assert_kind_of MyApplication::Billing::Nested::Firm, account.nested_qualified_billing_firm
    assert_kind_of MyApplication::Billing::Nested::Firm, account.nested_unqualified_billing_firm
  end

  def test_find_account_and_include_company
    account = MyApplication::Billing::Account.find(1, :include => :firm)
    assert_kind_of MyApplication::Business::Firm, account.instance_variable_get('@firm')
    assert_kind_of MyApplication::Business::Firm, account.firm
  end

  def test_table_name
    assert_equal 'accounts', MyApplication::Billing::Account.table_name, 'table_name for ActiveRecord model in module'
    assert_equal 'companies', MyApplication::Business::Client.table_name, 'table_name for ActiveRecord model subclass'
    assert_equal 'company_contacts', MyApplication::Business::Client::Contact.table_name, 'table_name for ActiveRecord model enclosed by another ActiveRecord model'
  end

  def test_eager_loading_in_modules
    # need to add an eager loading condition to force the eager loading model into
    # the old join model, to test that. See http://dev.rubyonrails.org/ticket/9640
    client_join_loaded = MyApplication::Business::Client.find(3, :include => {:firm => :account}, :conditions => 'accounts.id IS NOT NULL')
    client_sequential_loaded = MyApplication::Business::Client.find(3, :include => {:firm => :account})

    [client_join_loaded, client_sequential_loaded].each do |client|
      assert_no_queries do
        assert_not_nil(client.firm.account)
      end
    end
  end
end

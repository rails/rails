class AbstractCompany < ActiveRecord::Base
  self.abstract_class = true
end

class Company < AbstractCompany
  attr_protected :rating
  set_sequence_name :companies_nonstd_seq

  validates_presence_of :name

  has_one :dummy_account, :foreign_key => "firm_id", :class_name => "Account"
  has_many :contracts
  has_many :developers, :through => :contracts

  def arbitrary_method
    "I am Jack's profound disappointment"
  end

  private

  def private_method
    "I am Jack's innermost fears and aspirations"
  end
end

module Namespaced
  class Company < ::Company
  end

  class Firm < ::Company
    has_many :clients, :class_name => 'Namespaced::Client'
  end

  class Client < ::Company
  end
end

class Firm < Company
  has_many :clients, :order => "id", :dependent => :destroy, :counter_sql =>
      "SELECT COUNT(*) FROM companies WHERE firm_id = 1 " +
      "AND (#{QUOTED_TYPE} = 'Client' OR #{QUOTED_TYPE} = 'SpecialClient' OR #{QUOTED_TYPE} = 'VerySpecialClient' )"
  has_many :unsorted_clients, :class_name => "Client"
  has_many :clients_sorted_desc, :class_name => "Client", :order => "id DESC"
  has_many :clients_of_firm, :foreign_key => "client_of", :class_name => "Client", :order => "id"
  has_many :unvalidated_clients_of_firm, :foreign_key => "client_of", :class_name => "Client", :validate => false
  has_many :dependent_clients_of_firm, :foreign_key => "client_of", :class_name => "Client", :order => "id", :dependent => :destroy
  has_many :exclusively_dependent_clients_of_firm, :foreign_key => "client_of", :class_name => "Client", :order => "id", :dependent => :delete_all
  has_many :limited_clients, :class_name => "Client", :order => "id", :limit => 1
  has_many :clients_like_ms, :conditions => "name = 'Microsoft'", :class_name => "Client", :order => "id"
  has_many :clients_with_interpolated_conditions, :class_name => "Client", :conditions => 'rating > #{rating}'
  has_many :clients_like_ms_with_hash_conditions, :conditions => { :name => 'Microsoft' }, :class_name => "Client", :order => "id"
  has_many :clients_using_sql, :class_name => "Client", :finder_sql => 'SELECT * FROM companies WHERE client_of = #{id}'
  has_many :clients_using_counter_sql, :class_name => "Client",
           :finder_sql  => 'SELECT * FROM companies WHERE client_of = #{id}',
           :counter_sql => 'SELECT COUNT(*) FROM companies WHERE client_of = #{id}'
  has_many :clients_using_zero_counter_sql, :class_name => "Client",
           :finder_sql  => 'SELECT * FROM companies WHERE client_of = #{id}',
           :counter_sql => 'SELECT 0 FROM companies WHERE client_of = #{id}'
  has_many :no_clients_using_counter_sql, :class_name => "Client",
           :finder_sql  => 'SELECT * FROM companies WHERE client_of = 1000',
           :counter_sql => 'SELECT COUNT(*) FROM companies WHERE client_of = 1000'
  has_many :clients_using_finder_sql, :class_name => "Client", :finder_sql => 'SELECT * FROM companies WHERE 1=1'
  has_many :plain_clients, :class_name => 'Client'
  has_many :readonly_clients, :class_name => 'Client', :readonly => true
  has_many :clients_using_primary_key, :class_name => 'Client',
           :primary_key => 'name', :foreign_key => 'firm_name'
  has_many :clients_using_primary_key_with_delete_all, :class_name => 'Client',
           :primary_key => 'name', :foreign_key => 'firm_name', :dependent => :delete_all
  has_many :clients_grouped_by_firm_id, :class_name => "Client", :group => "firm_id", :select => "firm_id"
  has_many :clients_grouped_by_name, :class_name => "Client", :group => "name", :select => "name"

  has_one :account, :foreign_key => "firm_id", :dependent => :destroy, :validate => true
  has_one :unvalidated_account, :foreign_key => "firm_id", :class_name => 'Account', :validate => false
  has_one :account_with_select, :foreign_key => "firm_id", :select => "id, firm_id", :class_name=>'Account'
  has_one :readonly_account, :foreign_key => "firm_id", :class_name => "Account", :readonly => true
  has_one :account_using_primary_key, :primary_key => "firm_id", :class_name => "Account"
  has_one :account_using_foreign_and_primary_keys, :foreign_key => "firm_name", :primary_key => "name", :class_name => "Account"
  has_one :deletable_account, :foreign_key => "firm_id", :class_name => "Account", :dependent => :delete
  
  has_one :account_limit_500_with_hash_conditions, :foreign_key => "firm_id", :class_name => "Account", :conditions => { :credit_limit => 500 }

  has_one :unautosaved_account, :foreign_key => "firm_id", :class_name => 'Account', :autosave => false
  has_many :accounts
  has_many :unautosaved_accounts, :foreign_key => "firm_id", :class_name => 'Account', :autosave => false
end

class DependentFirm < Company
  has_one :account, :foreign_key => "firm_id", :dependent => :nullify
  has_many :companies, :foreign_key => 'client_of', :order => "id", :dependent => :nullify
end

class Client < Company
  belongs_to :firm, :foreign_key => "client_of"
  belongs_to :firm_with_basic_id, :class_name => "Firm", :foreign_key => "firm_id"
  belongs_to :firm_with_select, :class_name => "Firm", :foreign_key => "firm_id", :select => "id"
  belongs_to :firm_with_other_name, :class_name => "Firm", :foreign_key => "client_of"
  belongs_to :firm_with_condition, :class_name => "Firm", :foreign_key => "client_of", :conditions => ["1 = ?", 1]
  belongs_to :firm_with_primary_key, :class_name => "Firm", :primary_key => "name", :foreign_key => "firm_name"
  belongs_to :readonly_firm, :class_name => "Firm", :foreign_key => "firm_id", :readonly => true

  # Record destruction so we can test whether firm.clients.clear has
  # is calling client.destroy, deleting from the database, or setting
  # foreign keys to NULL.
  def self.destroyed_client_ids
    @destroyed_client_ids ||= Hash.new { |h,k| h[k] = [] }
  end

  before_destroy do |client|
    if client.firm
      Client.destroyed_client_ids[client.firm.id] << client.id
    end
    true
  end

  # Used to test that read and question methods are not generated for these attributes
  def ruby_type
    read_attribute :ruby_type
  end

  def rating?
    query_attribute :rating
  end

  class << self
    private

    def private_method
      "darkness"
    end
  end
end

class ExclusivelyDependentFirm < Company
  has_one :account, :foreign_key => "firm_id", :dependent => :delete
  has_many :dependent_sanitized_conditional_clients_of_firm, :foreign_key => "client_of", :class_name => "Client", :order => "id", :dependent => :delete_all, :conditions => "name = 'BigShot Inc.'"
  has_many :dependent_conditional_clients_of_firm, :foreign_key => "client_of", :class_name => "Client", :order => "id", :dependent => :delete_all, :conditions => ["name = ?", 'BigShot Inc.']
  has_many :dependent_hash_conditional_clients_of_firm, :foreign_key => "client_of", :class_name => "Client", :order => "id", :dependent => :delete_all, :conditions => {:name => 'BigShot Inc.'}
end

class SpecialClient < Client
end

class VerySpecialClient < SpecialClient
end

class Account < ActiveRecord::Base
  belongs_to :firm
  belongs_to :unautosaved_firm, :foreign_key => "firm_id", :class_name => "Firm", :autosave => false

  def self.destroyed_account_ids
    @destroyed_account_ids ||= Hash.new { |h,k| h[k] = [] }
  end

  before_destroy do |account|
    if account.firm
      Account.destroyed_account_ids[account.firm.id] << account.id
    end
    true
  end

  protected
    def validate
      errors.add_on_empty "credit_limit"
    end

  private

  def private_method
    "Sir, yes sir!"
  end
end

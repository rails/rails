class AbstractCompany < ActiveRecord::Base
  self.abstract_class = true
end

class Company < AbstractCompany
  self.sequence_name = :companies_nonstd_seq

  validates_presence_of :name

  has_one :dummy_account, foreign_key: "firm_id", class_name: "Account"
  has_many :contracts
  has_many :developers, through: :contracts

  scope :of_first_firm, lambda {
    joins(account: :firm).
    where("firms.id" => 1)
  }

  def arbitrary_method
    "I am Jack's profound disappointment"
  end

  private

    def private_method
      "I am Jack's innermost fears and aspirations"
    end

    class SpecialCo < Company
    end
end

module Namespaced
  class Company < ::Company
  end

  class Firm < ::Company
    has_many :clients, class_name: "Namespaced::Client"
  end

  class Client < ::Company
  end
end

class Firm < Company
  to_param :name

  has_many :clients, -> { order "id" }, dependent: :destroy, before_remove: :log_before_remove, after_remove: :log_after_remove
  has_many :unsorted_clients, class_name: "Client"
  has_many :unsorted_clients_with_symbol, class_name: :Client
  has_many :clients_sorted_desc, -> { order "id DESC" }, class_name: "Client"
  has_many :clients_of_firm, -> { order "id" }, foreign_key: "client_of", class_name: "Client", inverse_of: :firm
  has_many :clients_ordered_by_name, -> { order "name" }, class_name: "Client"
  has_many :unvalidated_clients_of_firm, foreign_key: "client_of", class_name: "Client", validate: false
  has_many :dependent_clients_of_firm, -> { order "id" }, foreign_key: "client_of", class_name: "Client", dependent: :destroy
  has_many :exclusively_dependent_clients_of_firm, -> { order "id" }, foreign_key: "client_of", class_name: "Client", dependent: :delete_all
  has_many :limited_clients, -> { limit 1 }, class_name: "Client"
  has_many :clients_with_interpolated_conditions, ->(firm) { where "rating > #{firm.rating}" }, class_name: "Client"
  has_many :clients_like_ms, -> { where("name = 'Microsoft'").order("id") }, class_name: "Client"
  has_many :clients_like_ms_with_hash_conditions, -> { where(name: "Microsoft").order("id") }, class_name: "Client"
  has_many :plain_clients, class_name: "Client"
  has_many :clients_using_primary_key, class_name: "Client",
           primary_key: "name", foreign_key: "firm_name"
  has_many :clients_using_primary_key_with_delete_all, class_name: "Client",
           primary_key: "name", foreign_key: "firm_name", dependent: :delete_all
  has_many :clients_grouped_by_firm_id, -> { group("firm_id").select("firm_id") }, class_name: "Client"
  has_many :clients_grouped_by_name, -> { group("name").select("name") }, class_name: "Client"

  has_one :account, foreign_key: "firm_id", dependent: :destroy, validate: true
  has_one :unvalidated_account, foreign_key: "firm_id", class_name: "Account", validate: false
  has_one :account_with_select, -> { select("id, firm_id") }, foreign_key: "firm_id", class_name: "Account"
  has_one :readonly_account, -> { readonly }, foreign_key: "firm_id", class_name: "Account"
  # added order by id as in fixtures there are two accounts for Rails Core
  # Oracle tests were failing because of that as the second fixture was selected
  has_one :account_using_primary_key, -> { order("id") }, primary_key: "firm_id", class_name: "Account"
  has_one :account_using_foreign_and_primary_keys, foreign_key: "firm_name", primary_key: "name", class_name: "Account"
  has_one :account_with_inexistent_foreign_key, class_name: "Account", foreign_key: "inexistent"
  has_one :deletable_account, foreign_key: "firm_id", class_name: "Account", dependent: :delete

  has_one :account_limit_500_with_hash_conditions, -> { where credit_limit: 500 }, foreign_key: "firm_id", class_name: "Account"

  has_one :unautosaved_account, foreign_key: "firm_id", class_name: "Account", autosave: false
  has_many :accounts
  has_many :unautosaved_accounts, foreign_key: "firm_id", class_name: "Account", autosave: false

  has_many :association_with_references, -> { references(:foo) }, class_name: "Client"

  has_one :lead_developer, class_name: "Developer"
  has_many :projects

  def log
    @log ||= []
  end

  private
    def log_before_remove(record)
      log << "before_remove#{record.id}"
    end

    def log_after_remove(record)
      log << "after_remove#{record.id}"
    end
end

class DependentFirm < Company
  has_one :account, foreign_key: "firm_id", dependent: :nullify
  has_many :companies, foreign_key: "client_of", dependent: :nullify
  has_one :company, foreign_key: "client_of", dependent: :nullify
end

class RestrictedWithExceptionFirm < Company
  has_one :account, -> { order("id") }, foreign_key: "firm_id", dependent: :restrict_with_exception
  has_many :companies, -> { order("id") }, foreign_key: "client_of", dependent: :restrict_with_exception
end

class RestrictedWithErrorFirm < Company
  has_one :account, -> { order("id") }, foreign_key: "firm_id", dependent: :restrict_with_error
  has_many :companies, -> { order("id") }, foreign_key: "client_of", dependent: :restrict_with_error
end

class Client < Company
  belongs_to :firm, foreign_key: "client_of"
  belongs_to :firm_with_basic_id, class_name: "Firm", foreign_key: "firm_id"
  belongs_to :firm_with_select, -> { select("id") }, class_name: "Firm", foreign_key: "firm_id"
  belongs_to :firm_with_other_name, class_name: "Firm", foreign_key: "client_of"
  belongs_to :firm_with_condition, -> { where "1 = ?", 1 }, class_name: "Firm", foreign_key: "client_of"
  belongs_to :firm_with_primary_key, class_name: "Firm", primary_key: "name", foreign_key: "firm_name"
  belongs_to :firm_with_primary_key_symbols, class_name: "Firm", primary_key: :name, foreign_key: :firm_name
  belongs_to :readonly_firm, -> { readonly }, class_name: "Firm", foreign_key: "firm_id"
  belongs_to :bob_firm, -> { where name: "Bob" }, class_name: "Firm", foreign_key: "client_of"
  has_many :accounts, through: :firm, source: :accounts
  belongs_to :account

  validate do
    firm
  end

  class RaisedOnSave < RuntimeError; end
  attr_accessor :raise_on_save
  before_save do
    raise RaisedOnSave if raise_on_save
  end

  class RaisedOnDestroy < RuntimeError; end
  attr_accessor :raise_on_destroy
  before_destroy do
    raise RaisedOnDestroy if raise_on_destroy
  end

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

  before_destroy :overwrite_to_raise

  # Used to test that read and question methods are not generated for these attributes
  def rating?
    query_attribute :rating
  end

  def overwrite_to_raise
  end

  class << self
    private

    def private_method
      "darkness"
    end
  end
end

class ExclusivelyDependentFirm < Company
  has_one :account, foreign_key: "firm_id", dependent: :delete
  has_many :dependent_sanitized_conditional_clients_of_firm, -> { order("id").where("name = 'BigShot Inc.'") }, foreign_key: "client_of", class_name: "Client", dependent: :delete_all
  has_many :dependent_conditional_clients_of_firm, -> { order("id").where("name = ?", "BigShot Inc.") }, foreign_key: "client_of", class_name: "Client", dependent: :delete_all
end

class SpecialClient < Client
end

class VerySpecialClient < SpecialClient
end

class Account < ActiveRecord::Base
  belongs_to :firm, class_name: "Company"
  belongs_to :unautosaved_firm, foreign_key: "firm_id", class_name: "Firm", autosave: false

  alias_attribute :available_credit, :credit_limit

  def self.destroyed_account_ids
    @destroyed_account_ids ||= Hash.new { |h,k| h[k] = [] }
  end

  # Test private kernel method through collection proxy using has_many.
  def self.open
    where("firm_name = ?", "37signals")
  end

  before_destroy do |account|
    if account.firm
      Account.destroyed_account_ids[account.firm.id] << account.id
    end
    true
  end

  validate :check_empty_credit_limit

  protected

    def check_empty_credit_limit
      errors.add("credit_limit", :blank) if credit_limit.blank?
    end

  private

    def private_method
      "Sir, yes sir!"
    end
end

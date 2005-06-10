class Company < ActiveRecord::Base
  attr_protected :rating

  validates_presence_of :name
end


class Firm < Company
  has_many :clients, :order => "id", :dependent => true, :counter_sql => "SELECT COUNT(*) FROM companies WHERE firm_id = 1 AND (type = 'Client' OR type = 'SpecialClient' OR type = 'VerySpecialClient' )"
  has_many :clients_sorted_desc, :class_name => "Client", :order => "id DESC"
  has_many :clients_of_firm, :foreign_key => "client_of", :class_name => "Client", :order => "id"
  has_many :clients_like_ms, :conditions => "name = 'Microsoft'", :class_name => "Client", :order => "id"
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

  has_one :account, :foreign_key => "firm_id", :dependent => true
end

class Client < Company
  belongs_to :firm, :foreign_key => "client_of"
  belongs_to :firm_with_basic_id, :class_name => "Firm", :foreign_key => "firm_id"
  belongs_to :firm_with_other_name, :class_name => "Firm", :foreign_key => "client_of"
  belongs_to :firm_with_condition, :class_name => "Firm", :foreign_key => "client_of", :conditions => "1 = 1"
end


class SpecialClient < Client
end

class VerySpecialClient < SpecialClient
end

class Account < ActiveRecord::Base
  belongs_to :firm
  
  protected
    def validate
      errors.add_on_empty "credit_limit"
    end
end

require File.dirname(__FILE__) + '/shared_setup'

logger = Logger.new(STDOUT)

# Database setup ---------------

logger.info "\nCreate tables"

[ "DROP TABLE companies", "DROP TABLE people", "DROP TABLE people_companies",
  "CREATE TABLE companies (id int(11) auto_increment, client_of int(11), name varchar(255), type varchar(100), PRIMARY KEY (id))",
  "CREATE TABLE people (id int(11) auto_increment, name varchar(100), PRIMARY KEY (id))",
  "CREATE TABLE people_companies (person_id int(11), company_id int(11), PRIMARY KEY (person_id, company_id))",
].each { |statement|
  # Tables doesn't necessarily already exist
  begin; ActiveRecord::Base.connection.execute(statement); rescue ActiveRecord::StatementInvalid; end
}


# Class setup ---------------

class Company < ActiveRecord::Base
  has_and_belongs_to_many :people, :class_name => "Person", :join_table => "people_companies", :table_name => "people"
end

class Firm < Company
  has_many :clients, :foreign_key => "client_of"

  def people_with_all_clients
    clients.inject([]) { |people, client| people + client.people }
  end
end

class Client < Company
  belongs_to :firm, :foreign_key => "client_of"
end

class Person < ActiveRecord::Base
  has_and_belongs_to_many :companies, :join_table => "people_companies"
  def self.table_name() "people" end
end


# Usage ---------------

logger.info "\nCreate fixtures"

Firm.new("name" => "Next Angle").save
Client.new("name" => "37signals", "client_of" => 1).save
Person.new("name" => "David").save


logger.info "\nUsing Finders"

next_angle = Company.find(1)
next_angle = Firm.find(1)    
next_angle = Company.find_first "name = 'Next Angle'"
next_angle = Firm.find_by_sql("SELECT * FROM companies WHERE id = 1").first

Firm === next_angle


logger.info "\nUsing has_many association"

next_angle.has_clients?
next_angle.clients_count
all_clients = next_angle.clients

thirty_seven_signals = next_angle.find_in_clients(2)


logger.info "\nUsing belongs_to association"

thirty_seven_signals.has_firm?
thirty_seven_signals.firm?(next_angle)


logger.info "\nUsing has_and_belongs_to_many association"

david = Person.find(1)
david.add_companies(thirty_seven_signals, next_angle)
david.companies.include?(next_angle)
david.companies_count == 2

david.remove_companies(next_angle)
david.companies_count == 1

thirty_seven_signals.people.include?(david)
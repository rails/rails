require File.dirname(__FILE__) + '/shared_setup'

logger = Logger.new(STDOUT)

# Database setup ---------------

logger.info "\nCreate tables"

[ "DROP TABLE people",
  "CREATE TABLE people (id int(11) auto_increment, name varchar(100), pass varchar(100), email varchar(100), PRIMARY KEY (id))"
].each { |statement|
  begin; ActiveRecord::Base.connection.execute(statement); rescue ActiveRecord::StatementInvalid; end # Tables doesn't necessarily already exist
}


# Class setup ---------------

class Person < ActiveRecord::Base
  # Using 
  def self.authenticate(name, pass)
    # find_first "name = '#{name}' AND pass = '#{pass}'" would be open to sql-injection (in a web-app scenario)
    find_first [ "name = '%s' AND pass = '%s'", name, pass ]
  end

  def self.name_exists?(name, id = nil)
    if id.nil?
      condition = [ "name = '%s'", name ]
    else
      # Check if anyone else than the person identified by person_id has that user_name
      condition = [ "name = '%s' AND id <> %d", name, id ]
    end

    !find_first(condition).nil?
  end

  def email_address_with_name
    "\"#{name}\" <#{email}>"
  end
        
  protected
    def validate
      errors.add_on_empty(%w(name pass email))
      errors.add("email", "must be valid") unless email_address_valid?
    end

    def validate_on_create
      if attribute_present?("name") && Person.name_exists?(name)
          errors.add("name", "is already taken by another person")
      end
    end

    def validate_on_update
      if attribute_present?("name") && Person.name_exists?(name, id)
          errors.add("name", "is already taken by another person")
      end
    end
  
  private
    def email_address_valid?() email =~ /\w[-.\w]*\@[-\w]+[-.\w]*\.\w+/ end
end

# Usage ---------------

logger.info "\nCreate fixtures"
david = Person.new("name" => "David Heinemeier Hansson", "pass" => "", "email" => "")
unless david.save
  puts "There was #{david.errors.count} error(s)"
  david.errors.each_full { |error| puts error }
end

david.pass = "something"
david.email = "invalid_address"
unless david.save
  puts "There was #{david.errors.count} error(s)"
  puts "It was email with: " + david.errors.on("email")
end

david.email = "david@loudthinking.com"
if david.save then puts "David finally made it!" end


another_david = Person.new("name" => "David Heinemeier Hansson", "pass" => "xc", "email" => "david@loudthinking")
unless another_david.save
  puts "Error on name: " + another_david.errors.on("name")
end
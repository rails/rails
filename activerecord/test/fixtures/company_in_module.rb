module MyApplication
  module Business
    class Company < ActiveRecord::Base
      attr_protected :rating
    end
    
    class Firm < Company
      has_many :clients, :order => "id", :dependent => true
      has_many :clients_sorted_desc, :class_name => "Client", :order => "id DESC"
      has_many :clients_of_firm, :foreign_key => "client_of", :class_name => "Client", :order => "id"
      has_many :clients_like_ms, :conditions => "name = 'Microsoft'", :class_name => "Client", :order => "id"
      has_many :clients_using_sql, :class_name => "Client", :finder_sql => 'SELECT * FROM companies WHERE client_of = #{id}'

      has_one :account, :dependent => true
    end

    class Client < Company
      belongs_to :firm, :foreign_key => "client_of"
      belongs_to :firm_with_other_name, :class_name => "Firm", :foreign_key => "client_of"
    end
    
    class Developer < ActiveRecord::Base
      has_and_belongs_to_many :projects

      protected
        def validate
          errors.add_on_boundary_breaking("name", 3..20)
      end
    end
    
    class Project < ActiveRecord::Base
      has_and_belongs_to_many :developers
    end

  end
  
  module Billing
    class Account < ActiveRecord::Base
      belongs_to :firm, :class_name => "MyApplication::Business::Firm"
      
      protected
        def validate
          errors.add_on_empty "credit_limit"
        end
    end
  end
end

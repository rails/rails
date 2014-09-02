require 'active_support/core_ext/object/with_options'

module MyApplication
  module Business
    class Company < ActiveRecord::Base
    end

    class Firm < Company
      has_many :clients, -> { order("id") }, :dependent => :destroy
      has_many :clients_sorted_desc, -> { order("id DESC") }, :class_name => "Client"
      has_many :clients_of_firm, -> { order "id" }, :foreign_key => "client_of", :class_name => "Client"
      has_many :clients_like_ms, -> { where("name = 'Microsoft'").order("id") }, :class_name => "Client"
      has_one :account, :class_name => 'MyApplication::Billing::Account', :dependent => :destroy
    end

    class Client < Company
      belongs_to :firm, :foreign_key => "client_of"
      belongs_to :firm_with_other_name, :class_name => "Firm", :foreign_key => "client_of"

      class Contact < ActiveRecord::Base; end
    end

    class Developer < ActiveRecord::Base
      has_and_belongs_to_many :projects
      validates_length_of :name, :within => (3..20)
    end

    class Project < ActiveRecord::Base
      has_and_belongs_to_many :developers
    end

    module Prefixed
      def self.table_name_prefix
        'prefixed_'
      end

      class Company < ActiveRecord::Base
      end

      class Firm < Company
        self.table_name = 'companies'
      end

      module Nested
        class Company < ActiveRecord::Base
        end
      end
    end

    module Suffixed
      def self.table_name_suffix
        '_suffixed'
      end

      class Company < ActiveRecord::Base
      end

      class Firm < Company
        self.table_name = 'companies'
      end

      module Nested
        class Company < ActiveRecord::Base
        end
      end
    end
  end

  module Billing
    class Firm < ActiveRecord::Base
      self.table_name = 'companies'
    end

    module Nested
      class Firm < ActiveRecord::Base
        self.table_name = 'companies'
      end
    end

    class Account < ActiveRecord::Base
      with_options(:foreign_key => :firm_id) do |i|
        i.belongs_to :firm, :class_name => 'MyApplication::Business::Firm'
        i.belongs_to :qualified_billing_firm, :class_name => 'MyApplication::Billing::Firm'
        i.belongs_to :unqualified_billing_firm, :class_name => 'Firm'
        i.belongs_to :nested_qualified_billing_firm, :class_name => 'MyApplication::Billing::Nested::Firm'
        i.belongs_to :nested_unqualified_billing_firm, :class_name => 'Nested::Firm'
      end

      validate :check_empty_credit_limit

      protected

      def check_empty_credit_limit
        errors.add_on_empty "credit_limit"
      end
    end
  end
end

class User
  include ActiveModel::MassAssignmentSecurity
  attr_protected :admin

  public :sanitize_for_mass_assignment
end

class SpecialUser
  include ActiveModel::MassAssignmentSecurity
  attr_accessible :name, :email, :as => :moderator

  public :sanitize_for_mass_assignment
end

class Person
  include ActiveModel::MassAssignmentSecurity
  attr_accessible :name, :email
  attr_accessible :name, :email, :admin, :as => :admin

  public :sanitize_for_mass_assignment
end

class SpecialPerson
  include ActiveModel::MassAssignmentSecurity
  include ActiveModel::ForbiddenAttributesProtection

  public :sanitize_for_mass_assignment
end

class Account
  include ActiveModel::MassAssignmentSecurity
  attr_accessible :name, :email, :as => [:default, :admin]
  attr_accessible :admin, :as => :admin

  public :sanitize_for_mass_assignment
end

class Firm
  include ActiveModel::MassAssignmentSecurity

  public :sanitize_for_mass_assignment

  def self.attributes_protected_by_default
    ["type"]
  end
end

class Task
  include ActiveModel::MassAssignmentSecurity
  attr_protected :starting

  public :sanitize_for_mass_assignment
end

class LoosePerson
  include ActiveModel::MassAssignmentSecurity
  attr_protected :credit_rating, :administrator
  attr_protected :credit_rating, :as => :admin
end

class LooseDescendant < LoosePerson
  attr_protected :phone_number
end

class LooseDescendantSecond< LoosePerson
  attr_protected :phone_number
  attr_protected :name
end

class TightPerson
  include ActiveModel::MassAssignmentSecurity
  attr_accessible :name, :address
  attr_accessible :name, :address, :admin, :as => :admin

  def self.attributes_protected_by_default
    ["mobile_number"]
  end
end

class TightDescendant < TightPerson
  attr_accessible :phone_number
  attr_accessible :super_powers, :as => :admin
end

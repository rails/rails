class OrganizationConnection < ActiveRecord::Base
  belongs_to :parent, :class_name => "Organization"
  belongs_to :from, :class_name => "Organization"
end

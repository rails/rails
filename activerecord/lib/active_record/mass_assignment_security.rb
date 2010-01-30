require 'active_record/mass_assignment_security/permission_set'

module ActiveRecord
  module MassAssignmentSecurity
    # Mass assignment security provides an interface for protecting attributes
    # from end-user assignment. For more complex permissions, mass assignment security
    # may be handled outside the model by extending a non-ActiveRecord class,
    # such as a controller, with this behavior.
    #
    # For example, a logged in user may need to assign additional attributes depending
    # on their role:
    #
    # class AccountsController < ApplicationController
    #   extend ActiveRecord::MassAssignmentSecurity
    #
    #   attr_accessible :first_name, :last_name
    #
    #   def self.admin_accessible_attributes
    #     accessible_attributes + [ :plan_id ]
    #   end
    #
    #   def update
    #     ...
    #     @account.update_attributes(account_params)
    #     ...
    #   end
    #
    #   protected
    #
    #   def account_params
    #     remove_attributes_protected_from_mass_assignment(params[:account])
    #   end
    #
    #   def mass_assignment_authorizer
    #     admin ? admin_accessible_attributes : super
    #   end
    #
    # end
    #
    def self.extended(base)
      base.send(:include, InstanceMethods)
    end

    module InstanceMethods

      protected

        def remove_attributes_protected_from_mass_assignment(attributes)
          mass_assignment_authorizer.sanitize(attributes)
        end

        def mass_assignment_authorizer
          self.class.mass_assignment_authorizer
        end

    end

    # Attributes named in this macro are protected from mass-assignment,
    # such as <tt>new(attributes)</tt>,
    # <tt>update_attributes(attributes)</tt>, or
    # <tt>attributes=(attributes)</tt>.
    #
    # Mass-assignment to these attributes will simply be ignored, to assign
    # to them you can use direct writer methods. This is meant to protect
    # sensitive attributes from being overwritten by malicious users
    # tampering with URLs or forms.
    #
    #   class Customer < ActiveRecord::Base
    #     attr_protected :credit_rating
    #   end
    #
    #   customer = Customer.new("name" => David, "credit_rating" => "Excellent")
    #   customer.credit_rating # => nil
    #   customer.attributes = { "description" => "Jolly fellow", "credit_rating" => "Superb" }
    #   customer.credit_rating # => nil
    #
    #   customer.credit_rating = "Average"
    #   customer.credit_rating # => "Average"
    #
    # To start from an all-closed default and enable attributes as needed,
    # have a look at +attr_accessible+.
    #
    # Note that using <tt>Hash#except</tt> or <tt>Hash#slice</tt> in place of +attr_protected+
    # to sanitize attributes won't provide sufficient protection.
    def attr_protected(*keys)
      use_authorizer(:protected_attributes)
      protected_attributes.merge(keys)
    end

    # Specifies a white list of model attributes that can be set via
    # mass-assignment, such as <tt>new(attributes)</tt>,
    # <tt>update_attributes(attributes)</tt>, or
    # <tt>attributes=(attributes)</tt>
    #
    # This is the opposite of the +attr_protected+ macro: Mass-assignment
    # will only set attributes in this list, to assign to the rest of
    # attributes you can use direct writer methods. This is meant to protect
    # sensitive attributes from being overwritten by malicious users
    # tampering with URLs or forms. If you'd rather start from an all-open
    # default and restrict attributes as needed, have a look at
    # +attr_protected+.
    #
    #   class Customer < ActiveRecord::Base
    #     attr_accessible :name, :nickname
    #   end
    #
    #   customer = Customer.new(:name => "David", :nickname => "Dave", :credit_rating => "Excellent")
    #   customer.credit_rating # => nil
    #   customer.attributes = { :name => "Jolly fellow", :credit_rating => "Superb" }
    #   customer.credit_rating # => nil
    #
    #   customer.credit_rating = "Average"
    #   customer.credit_rating # => "Average"
    #
    # Note that using <tt>Hash#except</tt> or <tt>Hash#slice</tt> in place of +attr_accessible+
    # to sanitize attributes won't provide sufficient protection.
    def attr_accessible(*keys)
      use_authorizer(:accessible_attributes)
      accessible_attributes.merge(keys)
    end

    # Returns an array of all the attributes that have been protected from mass-assignment.
    def protected_attributes
      read_inheritable_attribute(:protected_attributes) || begin
        authorizer = BlackList.new
        authorizer += attributes_protected_by_default
        authorizer.logger = logger
        write_inheritable_attribute(:protected_attributes, authorizer)
      end
    end

    # Returns an array of all the attributes that have been made accessible to mass-assignment.
    def accessible_attributes
      read_inheritable_attribute(:accessible_attributes) || begin
        authorizer = WhiteList.new
        authorizer.logger = logger
        write_inheritable_attribute(:accessible_attributes, authorizer)
      end
    end

    def mass_assignment_authorizer
      protected_attributes
    end

    private

      # Sets the active authorizer, (attr_protected or attr_accessible). Subsequent calls
      # will raise an exception when using a different authorizer_id.
      def use_authorizer(authorizer_id) # :nodoc:
        if active_authorizer_id = read_inheritable_attribute(:active_authorizer_id)
          unless authorizer_id == active_authorizer_id
            raise("Already using #{active_authorizer_id}, cannot use #{authorizer_id}")
          end
        else
          write_inheritable_attribute(:active_authorizer_id, authorizer_id)
        end
      end

  end
end

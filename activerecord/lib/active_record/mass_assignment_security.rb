require 'active_record/mass_assignment_security/permission_set'

module ActiveRecord
  # = Active Record Mass-Assignment Security
  module MassAssignmentSecurity
    extend ActiveSupport::Concern

    included do
      class_attribute :_accessible_attributes
      class_attribute :_protected_attributes
      class_attribute :_active_authorizer
    end

    # Mass assignment security provides an interface for protecting attributes
    # from end-user assignment. For more complex permissions, mass assignment security
    # may be handled outside the model by extending a non-ActiveRecord class,
    # such as a controller, with this behavior.
    #
    # For example, a logged in user may need to assign additional attributes depending
    # on their role:
    #
    # class AccountsController < ApplicationController
    #   include ActiveRecord::MassAssignmentSecurity
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
    #     sanitize_for_mass_assignment(params[:account])
    #   end
    #
    #   def mass_assignment_authorizer
    #     admin ? admin_accessible_attributes : super
    #   end
    #
    # end
    #
    module ClassMethods
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
      def attr_protected(*names)
        self._protected_attributes = self.protected_attributes + names
        self._active_authorizer = self._protected_attributes
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
      def attr_accessible(*names)
        self._accessible_attributes = self.accessible_attributes + names
        self._active_authorizer = self._accessible_attributes
      end

      def protected_attributes
        self._protected_attributes ||= BlackList.new(attributes_protected_by_default).tap { |w| w.logger = logger }
      end

      def accessible_attributes
        self._accessible_attributes ||= WhiteList.new.tap { |w| w.logger = logger }
      end

      def active_authorizer
        self._active_authorizer ||= protected_attributes
      end

      def attributes_protected_by_default
        []
      end
    end

    protected

      def sanitize_for_mass_assignment(attributes)
        mass_assignment_authorizer.sanitize(attributes)
      end

      def mass_assignment_authorizer
        self.class.active_authorizer
      end

  end
end

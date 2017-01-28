require 'active_support/core_ext/module/delegation'

module ActiveRecord
  module QueryDelegation
    delegate :find, :first, :first!, :last, :last!, :all, :exists?, :any?, :many?, :to => :scoped
    delegate :first_or_create, :first_or_create!, :first_or_initialize, :to => :scoped
    delegate :destroy, :destroy_all, :delete, :delete_all, :update, :update_all, :to => :scoped
    delegate :find_each, :find_in_batches, :to => :scoped
    delegate :select, :group, :order, :except, :reorder, :limit, :offset, :joins,
             :where, :preload, :eager_load, :includes, :from, :lock, :readonly,
             :having, :create_with, :uniq, :to => :scoped
    delegate :count, :average, :minimum, :maximum, :sum, :calculate, :pluck, :to => :scoped
    delegate :find_by_sql, :count_by_sql, :to => :scoped
  end
end

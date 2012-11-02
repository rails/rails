module ActiveRecord
  module QueryDelegation
    delegate :find, :take, :take!, :first, :first!, :last, :last!, :exists?, :any?, :many?, to: :all
    delegate :first_or_create, :first_or_create!, :first_or_initialize, to: :all
    delegate :find_or_create_by, :find_or_create_by!, :find_or_initialize_by, to: :all
    delegate :find_by, :find_by!, to: :all
    delegate :destroy, :destroy_all, :delete, :delete_all, :update, :update_all, to: :all
    delegate :find_each, :find_in_batches, to: :all
    delegate :select, :group, :order, :except, :reorder, :limit, :offset, :joins,
             :where, :preload, :eager_load, :includes, :from, :lock, :readonly,
             :having, :create_with, :uniq, :references, :none, to: :all
    delegate :count, :average, :minimum, :maximum, :sum, :calculate, :pluck, :ids, to: :all
    delegate :find_by_sql, :count_by_sql, to: :all
  end
end
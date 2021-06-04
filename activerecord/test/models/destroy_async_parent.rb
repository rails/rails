 # frozen_string_literal: true

 class DestroyAsyncParent < ActiveRecord::Base
   self.primary_key = "parent_id"

   has_one :dl_keyed_has_one, dependent: :destroy_async,
     foreign_key: :destroy_async_parent_id, primary_key: :parent_id
   has_many :dl_keyed_has_many, dependent: :destroy_async,
     foreign_key: :many_key, primary_key: :parent_id
   has_many :dl_keyed_join, dependent: :destroy_async,
     foreign_key: :destroy_async_parent_id, primary_key: :joins_key
   has_many :dl_keyed_has_many_through,
     through: :dl_keyed_join, dependent: :destroy_async,
     foreign_key: :dl_has_many_through_key_id, primary_key: :through_key
 end

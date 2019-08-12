 # frozen_string_literal: true

 class DestroyLaterParent < ActiveRecord::Base
   self.primary_key = "parent_id"

   has_one :dl_keyed_has_one, dependent: :destroy_later,
     foreign_key: :destroy_later_parent_id, primary_key: :parent_id
   has_many :dl_keyed_has_many, dependent: :destroy_later,
     foreign_key: :many_key, primary_key: :parent_id
   has_many :dl_keyed_join, dependent: :destroy_later,
     foreign_key: :destroy_later_parent_id, primary_key: :joins_key
   has_many :dl_keyed_has_many_through,
     through: :dl_keyed_join, dependent: :destroy_later,
     foreign_key: :dl_has_many_through_key_id, primary_key: :through_key

   has_many :taggings, as: :taggable, class_name: "Tagging"
   has_many :tags, -> { where name: "Der be rum" }, through: :taggings, dependent: :destroy_later

   destroy_later after: 10.days
 end

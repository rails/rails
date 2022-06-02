 # frozen_string_literal: true

 class DlKeyedJoin < ActiveRecord::Base
   self.primary_key = "joins_key"

   belongs_to :destroy_async_parent,
     primary_key: :parent_id
   belongs_to :dl_keyed_has_many_through,
     primary_key: :through_key
 end

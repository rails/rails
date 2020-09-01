 # frozen_string_literal: true

 class DestroyLaterParent < ActiveRecord::Base
   self.primary_key = "parent_id"

   destroy_later after: 10.days
 end

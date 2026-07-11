# frozen_string_literal: true

class ParcelItem < ActiveRecord::Base
  # Reproduces the automatic inverse_of gap real (default-config) apps hit:
  # the test suite's global_config.rb flips this to true suite-wide, which
  # would mask the bug this model exists to regression-test.
  self.automatically_invert_plural_associations = false

  belongs_to :parcel
  belongs_to :owner, class_name: "Buyer", foreign_key: "buyer_id", inverse_of: :owned_parcel_items
end

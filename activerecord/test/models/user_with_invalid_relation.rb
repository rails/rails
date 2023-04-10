# frozen_string_literal: true

class UserWithInvalidRelation < ActiveRecord::Base
  has_one :not_a_class

  has_one :class_name_provided_not_a_class, class_name: "NotAClass"

  has_one :account_invalid

  has_one :account_class_name, class_name: "AccountInvalid"

  has_many :user_info_invalid
  has_many :info_invalids, through: :user_info_invalid

  has_many :infos_class_name, through: :user_info, class_name: "InfoInvalid"

  has_many :user_infos_class_name, class_name: "UserInfoInvalid"
  has_many :infos_through_class_name, through: :user_infos_class_name, class_name: "InfoInvalid"
end

class AccountInvalid; end

class InfoInvalid; end

class UserInfoInvalid < ActiveRecord::Base
  belongs_to :info_invalid
  belongs_to :user_invalid
end

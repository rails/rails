class MemberLog < ActiveRecord::Base
  belongs_to :member
  belongs_to :error_log
end
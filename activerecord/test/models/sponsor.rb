class Sponsor < ActiveRecord::Base
  belongs_to :sponsor_club, class_name: "Club", foreign_key: "club_id"
  belongs_to :sponsorable, polymorphic: true
  belongs_to :thing, polymorphic: true, foreign_type: :sponsorable_type, foreign_key: :sponsorable_id
  belongs_to :sponsorable_with_conditions, -> { where name: "Ernie"}, polymorphic: true,
             foreign_type: "sponsorable_type", foreign_key: "sponsorable_id"
end

class Electron < ActiveRecord::Base
  belongs_to :molecule

  validates_presence_of :name

  cattr_reader :times_called_find_by_name
  @@times_called_find_by_name = 0

  def self.find_by_name(name)
    @@times_called_find_by_name += 1
    super(name)
  end
end

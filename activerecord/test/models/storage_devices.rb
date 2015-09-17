class StorageDevice < ActiveRecord::Base
  # default :type is HardDrive
  validates_inclusion_of :type, in: %w(HardDrive FlashDrive)
end

class HardDrive < StorageDevice
end

class FlashDrive < StorageDevice
end

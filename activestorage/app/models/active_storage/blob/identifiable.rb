# frozen_string_literal: true

module ActiveStorage::Blob::Identifiable
  def identify
    ActiveStorage::Identification.new(self).apply
  end

  def identified?
    identified
  end
end

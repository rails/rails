# frozen_string_literal: true

# = Active Storage \PassthroughVariant
#
# Wraps a blob to provide the same interface as an ActiveStorage::Variant
# without performing any image processing. Returned by
# ActiveStorage::Blob#variant_or_self when the blob's content type already
# matches one of the requested formats.
class ActiveStorage::PassthroughVariant
  attr_reader :blob

  delegate :key, :url, :download, :filename, :content_type, :service, to: :blob

  def initialize(blob)
    @blob = blob
  end

  def processed
    self
  end

  def image
    self
  end
end

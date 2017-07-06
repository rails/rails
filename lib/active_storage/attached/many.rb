class ActiveStorage::Attached::Many < ActiveStorage::Attached
  delegate_missing_to :attachments

  def attachments
    @attachments ||= ActiveStorage::Attachment.where(record_gid: record.to_gid.to_s, name: name)
  end

  def attach(*attachables)
    @attachments = attachments | Array(attachables).flatten.collect do |attachable|
      ActiveStorage::Attachment.create!(record_gid: record.to_gid.to_s, name: name, blob: create_blob_from(attachable))
    end
  end

  def attached?
    attachments.any?
  end

  def purge
    if attached?
      attachments.each(&:purge)
      @attachments = nil
    end
  end

  def purge_later
    if attached?
      attachments.each(&:purge_later)
      @attachments = nil
    end
  end
end

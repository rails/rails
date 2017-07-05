class ActiveVault::Attached::One < ActiveVault::Attached
  delegate_missing_to :attachment

  def attachment
    @attachment ||= ActiveVault::Attachment.find_by(record_gid: record.to_gid.to_s, name: name)
  end

  def attach(attachable)
    if @attachment
      # FIXME: Have options to declare dependent: :purge to clean up
    end

    @attachment = ActiveVault::Attachment.create!(record_gid: record.to_gid.to_s, name: name, blob: create_blob_from(attachable))
  end

  def attached?
    attachment.present?
  end

  def purge
    attachment.purge
    @attachment = nil
  end
end

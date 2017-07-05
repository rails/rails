require "active_vault/attachment"
require "action_dispatch/http/upload"

module ActiveVault::Attachments
  def has_file(name)
    define_method(name) do
      (@active_vault_attachments ||= {})[name] ||=
        ActiveVault::Attachment.find_by(record_gid: to_gid.to_s, name: name)&.tap { |a| a.record = self }
    end

    define_method(:"#{name}=") do |attachable|
      case attachable
      when ActiveVault::Blob
        blob = attachable
      when ActionDispatch::Http::UploadedFile
        blob = ActiveVault::Blob.create_after_upload! \
          io: attachable.open,
          filename: attachable.original_filename,
          content_type: attachable.content_type
      when Hash
        blob = ActiveVault::Blob.create_after_upload!(attachable)
      when NilClass
        blob = nil
      end

      (@active_vault_attachments ||= {})[name] = blob ?
        ActiveVault::Attachment.create!(record_gid: to_gid.to_s, name: name, blob: blob)&.tap { |a| a.record = self } : nil
    end
  end
end

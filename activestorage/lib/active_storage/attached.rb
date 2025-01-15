# frozen_string_literal: true


module ActiveStorage
  # = Active Storage \Attached
  #
  # Abstract base class for the concrete ActiveStorage::Attached::One and ActiveStorage::Attached::Many
  # classes that both provide proxy access to the blob association for a record.
  class Attached
    attr_reader :name, :record

    def initialize(name, record)
      @name, @record = name, record
    end

    private
      def change
        record.attachment_changes[name]
      end

      def base64_data?(data)
        data.is_a?(String) && data.match?(/^data:.*;base64,/)
      end

      def decode_base64_attachable(data)
        metadata, base64_content = data.split(',', 2)
        mime_type = metadata.match(/^data:(.*);base64$/)[1]
        filename = "uploaded_file.#{mime_type.split('/').last}"
        content = Base64.decode64(base64_content)
        { io: StringIO.new(content), filename:, content_type: mime_type }
      end
  end
end

require "active_storage/attached/model"
require "active_storage/attached/one"
require "active_storage/attached/many"
require "active_storage/attached/changes"

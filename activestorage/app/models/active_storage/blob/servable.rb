# frozen_string_literal: true

module ActiveStorage::Blob::Servable # :nodoc:
  def content_type_for_serving
    forcibly_serve_as_binary? ? ActiveStorage.binary_content_type : content_type
  end

  def forced_disposition_for_serving
    if forcibly_serve_as_binary? || !allowed_inline?
      :attachment
    end
  end

  private
    def forcibly_serve_as_binary?
      ActiveStorage.content_types_to_serve_as_binary.include?(content_type)
    end

    def allowed_inline?
      ActiveStorage.content_types_allowed_inline.include?(content_type)
    end
end

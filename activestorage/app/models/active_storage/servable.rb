# frozen_string_literal: true

# Provides serving helpers for blob-like records and previews.
module ActiveStorage::Servable
  def content_type_for_serving
    forcibly_serve_as_binary? ? ActiveStorage.binary_content_type : content_type
  end

  def forced_disposition_for_serving
    if forcibly_serve_as_binary? || !allowed_inline?
      :attachment
    end
  end

  private
    def with_writing_role(&block)
      # Servable is part of the backend contract and is included directly by
      # blob-like records (e.g. ActiveStorage::Blob), which are their own blob;
      # fall back to +self+ when the includer does not expose +blob+.
      target = respond_to?(:blob) ? blob : self
      if defined?(::ActiveRecord::Base) && target.is_a?(::ActiveRecord::Base)
        ::ActiveRecord::Base.connected_to(role: ::ActiveRecord.writing_role, &block)
      else
        yield
      end
    end

    def forcibly_serve_as_binary?
      ActiveStorage.content_types_to_serve_as_binary.include?(content_type)
    end

    def allowed_inline?
      ActiveStorage.content_types_allowed_inline.include?(content_type)
    end
end

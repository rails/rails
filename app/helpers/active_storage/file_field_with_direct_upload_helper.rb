module ActiveStorage
  # Temporary hack to overwrite the default file_field_tag and Form#file_field to accept a direct_upload: true option
  # that then gets replaced with a data-direct-upload-url attribute with the route prefilled.
  module FileFieldWithDirectUploadHelper
    def file_field_tag(name, options = {})
      text_field_tag(name, nil, convert_direct_upload_option_to_url(options.merge(type: :file)))
    end

    def file_field(object_name, method, options = {})
      ActionView::Helpers::Tags::FileField.new(object_name, method, self, convert_direct_upload_option_to_url(options)).render
    end

    private
      def convert_direct_upload_option_to_url(options)
        options.merge('data-direct-upload-url': options.delete(:direct_upload) ? rails_direct_uploads_url : nil).compact
      end
  end
end

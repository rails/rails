# -*- encoding: utf-8 -*-
# stub: activestorage 6.1.0.alpha ruby lib

Gem::Specification.new do |s|
  s.name = "activestorage".freeze
  s.version = "6.1.0.alpha"

  s.required_rubygems_version = Gem::Requirement.new("> 1.3.1".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "changelog_uri" => "https://github.com/rails/rails/blob/v6.1.0.alpha/activestorage/CHANGELOG.md", "source_code_uri" => "https://github.com/rails/rails/tree/v6.1.0.alpha/activestorage" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["David Heinemeier Hansson".freeze]
  s.date = "2019-10-05"
  s.description = "Attach cloud and local files in Rails applications.".freeze
  s.email = "david@loudthinking.com".freeze
  s.files = ["CHANGELOG.md".freeze, "MIT-LICENSE".freeze, "README.md".freeze, "app/assets/javascripts/activestorage.js".freeze, "app/controllers/active_storage".freeze, "app/controllers/active_storage/base_controller.rb".freeze, "app/controllers/active_storage/blobs_controller.rb".freeze, "app/controllers/active_storage/direct_uploads_controller.rb".freeze, "app/controllers/active_storage/disk_controller.rb".freeze, "app/controllers/active_storage/representations_controller.rb".freeze, "app/controllers/concerns/active_storage".freeze, "app/controllers/concerns/active_storage/set_blob.rb".freeze, "app/controllers/concerns/active_storage/set_current.rb".freeze, "app/javascript/activestorage".freeze, "app/javascript/activestorage/blob_record.js".freeze, "app/javascript/activestorage/blob_upload.js".freeze, "app/javascript/activestorage/direct_upload.js".freeze, "app/javascript/activestorage/direct_upload_controller.js".freeze, "app/javascript/activestorage/direct_uploads_controller.js".freeze, "app/javascript/activestorage/file_checksum.js".freeze, "app/javascript/activestorage/helpers.js".freeze, "app/javascript/activestorage/index.js".freeze, "app/javascript/activestorage/ujs.js".freeze, "app/jobs/active_storage".freeze, "app/jobs/active_storage/analyze_job.rb".freeze, "app/jobs/active_storage/base_job.rb".freeze, "app/jobs/active_storage/mirror_job.rb".freeze, "app/jobs/active_storage/purge_job.rb".freeze, "app/models/active_storage".freeze, "app/models/active_storage/attachment.rb".freeze, "app/models/active_storage/blob".freeze, "app/models/active_storage/blob.rb".freeze, "app/models/active_storage/blob/analyzable.rb".freeze, "app/models/active_storage/blob/identifiable.rb".freeze, "app/models/active_storage/blob/representable.rb".freeze, "app/models/active_storage/current.rb".freeze, "app/models/active_storage/filename.rb".freeze, "app/models/active_storage/preview.rb".freeze, "app/models/active_storage/variant.rb".freeze, "app/models/active_storage/variation.rb".freeze, "config/routes.rb".freeze, "db/migrate/20170806125915_create_active_storage_tables.rb".freeze, "db/update_migrate".freeze, "db/update_migrate/20190112182829_add_service_name_to_active_storage_blobs.rb".freeze, "lib/active_storage".freeze, "lib/active_storage.rb".freeze, "lib/active_storage/analyzer".freeze, "lib/active_storage/analyzer.rb".freeze, "lib/active_storage/analyzer/image_analyzer.rb".freeze, "lib/active_storage/analyzer/null_analyzer.rb".freeze, "lib/active_storage/analyzer/video_analyzer.rb".freeze, "lib/active_storage/attached".freeze, "lib/active_storage/attached.rb".freeze, "lib/active_storage/attached/changes".freeze, "lib/active_storage/attached/changes.rb".freeze, "lib/active_storage/attached/changes/create_many.rb".freeze, "lib/active_storage/attached/changes/create_one.rb".freeze, "lib/active_storage/attached/changes/create_one_of_many.rb".freeze, "lib/active_storage/attached/changes/delete_many.rb".freeze, "lib/active_storage/attached/changes/delete_one.rb".freeze, "lib/active_storage/attached/many.rb".freeze, "lib/active_storage/attached/model.rb".freeze, "lib/active_storage/attached/one.rb".freeze, "lib/active_storage/downloader.rb".freeze, "lib/active_storage/downloading.rb".freeze, "lib/active_storage/engine.rb".freeze, "lib/active_storage/errors.rb".freeze, "lib/active_storage/gem_version.rb".freeze, "lib/active_storage/log_subscriber.rb".freeze, "lib/active_storage/previewer".freeze, "lib/active_storage/previewer.rb".freeze, "lib/active_storage/previewer/mupdf_previewer.rb".freeze, "lib/active_storage/previewer/poppler_pdf_previewer.rb".freeze, "lib/active_storage/previewer/video_previewer.rb".freeze, "lib/active_storage/reflection.rb".freeze, "lib/active_storage/service".freeze, "lib/active_storage/service.rb".freeze, "lib/active_storage/service/azure_storage_service.rb".freeze, "lib/active_storage/service/configurator.rb".freeze, "lib/active_storage/service/disk_service.rb".freeze, "lib/active_storage/service/gcs_service.rb".freeze, "lib/active_storage/service/mirror_service.rb".freeze, "lib/active_storage/service/s3_service.rb".freeze, "lib/active_storage/service_registry.rb".freeze, "lib/active_storage/transformers".freeze, "lib/active_storage/transformers/image_processing_transformer.rb".freeze, "lib/active_storage/transformers/mini_magick_transformer.rb".freeze, "lib/active_storage/transformers/transformer.rb".freeze, "lib/active_storage/version.rb".freeze, "lib/tasks/activestorage.rake".freeze]
  s.homepage = "https://rubyonrails.org".freeze
  s.licenses = ["MIT".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 2.5.0".freeze)
  s.rubygems_version = "3.0.3".freeze
  s.summary = "Local and cloud file storage framework.".freeze

  s.installed_by_version = "3.0.3" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 4

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<activesupport>.freeze, ["= 6.1.0.alpha"])
      s.add_runtime_dependency(%q<actionpack>.freeze, ["= 6.1.0.alpha"])
      s.add_runtime_dependency(%q<activejob>.freeze, ["= 6.1.0.alpha"])
      s.add_runtime_dependency(%q<activerecord>.freeze, ["= 6.1.0.alpha"])
      s.add_runtime_dependency(%q<marcel>.freeze, ["~> 0.3.1"])
    else
      s.add_dependency(%q<activesupport>.freeze, ["= 6.1.0.alpha"])
      s.add_dependency(%q<actionpack>.freeze, ["= 6.1.0.alpha"])
      s.add_dependency(%q<activejob>.freeze, ["= 6.1.0.alpha"])
      s.add_dependency(%q<activerecord>.freeze, ["= 6.1.0.alpha"])
      s.add_dependency(%q<marcel>.freeze, ["~> 0.3.1"])
    end
  else
    s.add_dependency(%q<activesupport>.freeze, ["= 6.1.0.alpha"])
    s.add_dependency(%q<actionpack>.freeze, ["= 6.1.0.alpha"])
    s.add_dependency(%q<activejob>.freeze, ["= 6.1.0.alpha"])
    s.add_dependency(%q<activerecord>.freeze, ["= 6.1.0.alpha"])
    s.add_dependency(%q<marcel>.freeze, ["~> 0.3.1"])
  end
end

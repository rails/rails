get  "/rails/active_storage/disk/:encoded_key/*filename" => "active_storage/disk#show", as: :rails_disk_blob
get  "/rails/active_storage/variants/:encoded_key/:encoded_transformation/*filename" => "active_storage/controllers/variants#show", as: :rails_blob_variant
post "/rails/active_storage/direct_uploads" => "active_storage/direct_uploads#create", as: :rails_direct_uploads

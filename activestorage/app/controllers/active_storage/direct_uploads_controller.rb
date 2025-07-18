# frozen_string_literal: true

# Creates a new blob on the server side in anticipation of a direct-to-service upload from the client side.
# When the client-side upload is completed, the signed_blob_id can be submitted as part of the form to reference
# the blob that was created up front.
#
# WARNING: All Active Storage controllers are publicly accessible by default. The
# generated URLs are hard to guess, but permanent by design. If your files
# require a higher level of protection consider implementing
# {Authenticated Controllers}[https://guides.rubyonrails.org/active_storage_overview.html#authenticated-controllers].
#
# If you implement your own controller, you will also need to add a new route, and provide that route to the
# +direct_upload_url+ option for file inputs.
class ActiveStorage::DirectUploadsController < ActiveStorage::BaseController
  include ActiveStorage::SetDirectUpload
end

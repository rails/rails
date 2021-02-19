*   Add `ActiveStorage::Streaming` module that can be included in a controller to get access to `#send_blob_stream`,
    which wraps the new `ActionController::Base#send_stream` method to stream a blob from cloud storage:
    
    ```ruby
    class MyPublicBlobsController < ApplicationController
      include ActiveStorage::SetBlob, ActiveStorage::Streaming
      
      def show
        http_cache_forever(public: true) do
          send_blob_stream @blob, disposition: params[:disposition]
        end
      end
    end
    ```
    
    *DHH*

*   Add ability to use pre-defined variants.

    ```ruby
    class User < ActiveRecord::Base
      has_one_attached :avatar do |attachable|
        attachable.variant :thumb, resize: "100x100"
        attachable.variant :medium, resize: "300x300", monochrome: true
      end
    end

    class Gallery < ActiveRecord::Base
      has_many_attached :photos do |attachable|
        attachable.variant :thumb, resize: "100x100"
        attachable.variant :medium, resize: "300x300", monochrome: true
      end
    end

    <%= image_tag user.avatar.variant(:thumb) %>
    ```

    *fatkodima*

*   After setting `config.active_storage.resolve_model_to_route = :rails_storage_proxy`
    `rails_blob_path` and `rails_representation_path` will generate proxy URLs by default.

    *Ali Ismayilov*

*   Declare `ActiveStorage::FixtureSet` and `ActiveStorage::FixtureSet.blob` to
    improve fixture integration

    *Sean Doyle*

Please check [6-1-stable](https://github.com/rails/rails/blob/6-1-stable/activestorage/CHANGELOG.md) for previous changes.

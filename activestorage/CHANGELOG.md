*   Add `download_with_index` method 

    If you need to download files by chunks, you could send a block to the download method.
    However, if for some reason the execution of this block failed, 
    there was no way to resume the processing from the last successfully processed chunk.
    
    To take advantage of those previous chunks, it was necessary to re-implement
    the reading of files by chunks, using the `download_chunk` method,
    keeping a record of the execution point and updating offsets (something like a local pagination of chunks)
    
    With the `download_with_index` method we will receive the chunk and (optionally) the current index in each block.
    In case of failures, you only need to restart the execution with the index

    *Pablo Soldi*
    
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

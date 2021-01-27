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
    
*   Declare `ActiveStorage::FixtureSet` and `ActiveStorage::FixtureSet.blob` to
    improve fixture integration

    *Sean Doyle*

Please check [6-1-stable](https://github.com/rails/rails/blob/6-1-stable/activestorage/CHANGELOG.md) for previous changes.

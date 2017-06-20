*   Fix issues with scopes and engine on `current_page?` method. 
    
    Fixes #29401.
    
    *Nikita Savrov*
    
*   Generate field ids in `collection_check_boxes` and `collection_radio_buttons`.

    This makes sure that the labels are linked up with the fields.

    Fixes #29014.

    *Yuji Yaginuma*

*   Add `:json` type to `auto_discovery_link_tag` to support [JSON Feeds](https://jsonfeed.org/version/1)

    *Mike Gunderloy*

*   Update `distance_of_time_in_words` helper to display better error messages
    for bad input.

    *Jay Hayes*


Please check [5-1-stable](https://github.com/rails/rails/blob/5-1-stable/actionview/CHANGELOG.md) for previous changes.

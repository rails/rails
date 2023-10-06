*   Add `ActiveRecord::Base::attributes_of_type`, which returns the names of
    attributes that are of a specified type.  Using this method in conjunction
    with `normalizes`, you can write something like:

      ```ruby
      class Post < ActiveRecord::Base
        normalizes attributes_of_type(:string), with: -> { _1.strip }
      end
      ```

    which will strip all string attributes.

    *Jonathan Hefner*

*   Ensure `#signed_id` outputs `url_safe` strings.

    *Jason Meller*

Please check [7-1-stable](https://github.com/rails/rails/blob/7-1-stable/activerecord/CHANGELOG.md) for previous changes.

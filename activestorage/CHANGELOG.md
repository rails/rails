*   Return attachment record(s) instead of boolean value after successful attach.

    This new behaviour will return attachment record(s) after successfully attached to db.

    Old behaviour was to return boolean value to check whether attach successful or not.

    ```ruby
    attached = @user.highlights.attach(create_blob(filename: "funky.jpg"), create_blob(filename: "town.jpg"))
    ```

    *Sinan Keskin*

Please check [7-0-stable](https://github.com/rails/rails/blob/7-0-stable/activestorage/CHANGELOG.md) for previous changes.

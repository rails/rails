*   Support attaching `URI` instances

    ```ruby
    uri = URI("https://example.com/racecar.jpg")

    user.avatar.attach uri

    user.avatar.filename.to_s
    # => "racecar.jpg"
    ```

    *Sean Doyle*

Please check [8-0-stable](https://github.com/rails/rails/blob/8-0-stable/activestorage/CHANGELOG.md) for previous changes.

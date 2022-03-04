* Set the value of the explicit `:value` option to `data-disable-with`

    ```ruby
    = f.submit value: '選択する'

    # Before
    # => <input type="submit" name="commit" value="選択する" data-disable-with="登録する">
    # After
    # => <input type="submit" name="commit" value="選択する" data-disable-with="選択する">
    ```

    *Noriyo Akita*


* Ensure models passed to `form_for` attempt to call `to_model`.

    *Sean Doyle*

Please check [7-0-stable](https://github.com/rails/rails/blob/7-0-stable/actionview/CHANGELOG.md) for previous changes.

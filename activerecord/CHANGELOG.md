*   Add `normalizes_type` to apply normalizations to multiple attributes of the same type.

    ```ruby
    class User < ActiveRecord::Base
      normalizes_type :string, except: :name, with: -> attribute { attribute.strip }
    end
    ```

    *Niklas Häusele*

Please check [7-1-stable](https://github.com/rails/rails/blob/7-1-stable/activerecord/CHANGELOG.md) for previous changes.

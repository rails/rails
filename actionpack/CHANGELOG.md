* Add #helpers method to `ActionController` that exposes all the helpers.
This is so that insted of doing something like:

    ```
    class User < ActiveRecord::Base
      include Rails.applicatioon.routes.url_helpers

      def self.my_path
        user_path(self)
      end
    end
    ```

One can use the shorthand:

    ```
    def self.my_path
      ApplicationController.helpers.user_path(self)
    end
    ```

And also avoid including a module in their models.

  *Guilherme Mansur*


* Fix strong parameters blocks all attributes even when only some keys are invalid (non-numerical). It should only block invalid key's values instead.

    *Stan Lo*

Please check [6-0-stable](https://github.com/rails/rails/blob/6-0-stable/actionpack/CHANGELOG.md) for previous changes.

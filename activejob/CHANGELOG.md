*   Introduce `ActiveJob::Base.locator_options` to support strict loading

    ```ruby
    class Article < ApplicationRecord
      self.strict_loading_by_default = true

      has_and_belongs_to_many :tags
    end

    class Tag < ApplicationRecord
      has_and_belongs_to_many :articles
    end

    class PublishJob < ApplicationJob
      locator_options "Article", includes: :tags

      def perform(article)
        article.tags.each do |tag|
          # ...
        end
      end
    end
    ```

    *Sean Doyle*

*   Fix using custom serializers with `ActiveJob::Arguments.serialize` when
    `ActiveJob::Base` hasn't been loaded.

    *Hartley McGuire*

Please check [8-1-stable](https://github.com/rails/rails/blob/8-1-stable/activejob/CHANGELOG.md) for previous changes.

*   Introducing immediate variants that are created simultaneously with the attachment.
    ```
      has_one_attached :avatar |attachable|
        attachable.variant :thumb, resize_to_limit: [4, 4], immediate: true
      end
    ```
    This approach is useful when the attached file experiences high traffic, potentially generating hundreds or thousands of requests, each attempting to create the variant. In such scenarios, this allows the same process responsible for creating the attachment to immediately create variants identified with the `immediate` option.
    *Tom Rossi*

Please check [7-2-stable](https://github.com/rails/rails/blob/7-2-stable/activestorage/CHANGELOG.md) for previous changes.

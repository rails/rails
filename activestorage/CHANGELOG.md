*  The S3 service now permits uploading files larger than 5 gigabytes.

   When uploading a file greater than 100 megabytes in size, the service
   transparently switches to [multipart uploads](https://docs.aws.amazon.com/AmazonS3/latest/dev/mpuoverview.html)
   using a part size computed from the file's total size and S3's part count limit.

   No application changes are necessary to take advantage of this feature. You
   can customize the default 100 MB multipart upload threshold in your S3
   service's configuration:

   ```yaml
   production:
     service: s3
     access_key_id: <%= Rails.application.credentials.dig(:aws, :access_key_id) %>
     secret_access_key: <%= Rails.application.credentials.dig(:aws, :secret_access_key) %>
     region: us-east-1
     bucket: my-bucket
     upload:
       multipart_threshold: <%= 250.megabytes %>
   ```

   *George Claghorn*

Please check [6-0-stable](https://github.com/rails/rails/blob/6-0-stable/activestorage/CHANGELOG.md) for previous changes.

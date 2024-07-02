*   Add `type` attribute in source tag of video and audio

    ```ruby
    # Before
    video_tag("movie.mp4", "movie.webm")
    # => <video><source src="movie.mp4" /><source src="movie.webm" /></video>

    # After
    video_tag("movie.mp4", "movie.webm")
    # => <video><source src="movie.mp4" type="video/mp4" /><source src="movie.webm" type="video/webm" /></video>
    ```

    *heka1024*

Please check [7-2-stable](https://github.com/rails/rails/blob/7-2-stable/actionview/CHANGELOG.md) for previous changes.

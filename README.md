# eiden.ca

Jekyll blog, served by GitHub Pages at https://www.eiden.ca. Every push to `master` is live in about a minute.

## Write

```sh
bin/new-post "My post title" Tag1 Tag2   # creates _drafts/my-post-title.md
bin/serve                                # preview at http://localhost:4000, drafts included, live reload
bin/publish _drafts/my-post-title.md     # moves it to _posts/ with today's date and commits
git push                                 # live
```

Images for new posts go in `assets/img/<slug>/` and are linked as `/assets/img/<slug>/picture.png`.
Older posts hotlink images from `raw.githubusercontent.com/.../master/_posts/...`, so don't rename
`master` or move those folders.

No local setup? Press `.` on the GitHub repo page to edit in the browser, and commit to `master`.

## Local setup (once)

`bin/serve` needs Ruby 3.2+ (macOS: `brew install ruby@3.3`). It installs gems into `vendor/` on first run.

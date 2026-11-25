#!/bin/sh
# Run in gitlab-rails after fork.patch. The patch is made against the 19.7 sources, and three hunks
# of the diff-hiding change have a context that older releases (19.5) do not have. The expected
# rejects are replaced here by the same one-line insertions. Any other reject fails the build.
set -eu

expected="app/models/merge_request_diff.rb.rej lib/gitlab/git/diff.rb.rej lib/gitlab/git/diff_collection.rb.rej"

for rej in $(find . -name '*.rej' | sed 's|^\./||'); do
  case " $expected " in
    *" $rej "*) ;;
    *) echo "unexpected reject: $rej" >&2; exit 1 ;;
  esac
done

if [ -e app/models/merge_request_diff.rb.rej ]; then
  sed -i '/options\[:generated_files\] = compare\.generated_files/a\      options[:ui_ignore] = ui_ignore' app/models/merge_request_diff.rb
fi
if [ -e lib/gitlab/git/diff.rb.rej ]; then
  sed -i 's/:generated_files, :offset_index\]/:generated_files, :offset_index, :ui_ignore]/' lib/gitlab/git/diff.rb
fi
if [ -e lib/gitlab/git/diff_collection.rb.rej ]; then
  sed -i '/@generated_files = options\.fetch(:generated_files, nil)/a\        @ui_ignore = options.fetch(:ui_ignore, nil)\n        @ui_ignore = nil if @ui_ignore\&.empty?' lib/gitlab/git/diff_collection.rb
fi
find . -name '*.rej' -delete

grep -q 'options\[:ui_ignore\] = ui_ignore' app/models/merge_request_diff.rb
grep -q ':offset_index.*:ui_ignore\|^ *:ui_ignore\]' lib/gitlab/git/diff.rb
grep -q '@ui_ignore = options.fetch(:ui_ignore, nil)' lib/gitlab/git/diff_collection.rb
echo "compat ok"

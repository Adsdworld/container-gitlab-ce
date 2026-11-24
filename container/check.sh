#!/usr/bin/env bash
# Run inside the built image, with this directory mounted on /check. GitLab is not started: the
# patched Ruby files must parse, and the pattern matching of hidden files must behave.
set -euo pipefail

ruby=/opt/gitlab/embedded/bin/ruby
cd /opt/gitlab/embedded/service/gitlab-rails

grep '^+++ b/' /check/fork.patch | cut -c7- | grep '\.rb$' | while read -r file; do
  "$ruby" -wc "$file" > /dev/null
done

"$ruby" -e '
  module Gitlab; module Diff; end; end
  load "lib/gitlab/diff/ui_ignore.rb"
  ignore = Gitlab::Diff::UiIgnore.from_patterns(["graphify-out/", "*.lock", "docs/**/*.md", "/root.txt"])
  abort "ui_ignore: should hide"  unless ignore.ignored?("a/graphify-out/graph.json") && ignore.ignored?("yarn.lock") &&
    ignore.ignored?("docs/a/b.md") && ignore.ignored?("root.txt")
  abort "ui_ignore: should show"  if ignore.ignored?("graphify-outer/x") || ignore.ignored?("app/x.rb") || ignore.ignored?("a/root.txt")
  puts "ui_ignore ok"
'

test -f app/services/ci/precommit/amend_commit_service.rb
grep -q 'precommit: 20' app/models/concerns/enums/ci/pipeline.rb

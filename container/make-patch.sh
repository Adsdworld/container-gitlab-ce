#!/usr/bin/env bash
# Writes the backend changes of this fork, relative to the imported upstream, as a patch that
# applies on the gitlab-rails directory of an official GitLab CE image.
#
#   container/make-patch.sh [base-ref] [head-ref] > container/fork.patch
#
# Specs, docs and frontend sources are left out: the image ships compiled assets, so a Vue or
# JavaScript change would not take effect without rebuilding them.
set -euo pipefail

base=${1:-origin/upstream-import}
head=${2:-HEAD}

git diff "$base" "$head" -- app lib config \
  ':(exclude)app/assets' ':(exclude)app/components/**/*.js'

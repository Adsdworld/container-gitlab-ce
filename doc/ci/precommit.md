---
stage: Verify
group: Pipeline Execution
info: custom fork feature, not part of upstream GitLab
title: Precommit pipelines
---

A precommit pipeline runs before the regular pipeline of a branch that has an open merge request.
Its jobs run on normal runners. The files they leave in their artifacts are added to the commit that
was pushed, which is replaced by the same commit with those files. The regular pipeline then runs on
that commit.

## Configuration

Add `gitlab-precommit.yaml` at the root of the repository. It holds CI jobs, and a reserved
`precommit` block:

```yaml
precommit:
  commit_paths: [graphify-out/]  # the only paths the jobs may write into the commit
  hide_in_ui: [graphify-out/]    # hidden in merge request diffs (.gitignore syntax)

graphify:
  image: { name: ghcr.io/adsdworld/container-graphify:latest, entrypoint: [""] }
  script: [graphify-build]
  artifacts:
    paths: [graphify-out/]
```

- The file is read on the **target branch** of the merge request, not on the source branch, so a
  merge request cannot change what it may write. A change to the file applies after it is merged.
- `precommit: { enabled: false }` turns the feature off. Without the file, nothing changes.
- Only branches of the same project with an open merge request get a precommit pipeline.
- `commit_paths` cannot reach `.gitlab-ci.yml`, `gitlab-precommit.yaml`, `.gitattributes`,
  `.gitmodules`, `.gitignore`, `CODEOWNERS`, `.gitlab/`, `.github/` or any `.git` path.

## Behavior

- If the precommit pipeline fails, or nothing changes, the regular pipeline runs on the commit as
  it was pushed.
- If two jobs write the same path with different content, or an artifact is not a regular file,
  nothing is added.
- The commit keeps its parent and message. Its author is the GitLab user of the commit email, or the
  user who pushed. The author date changes and the original signature is lost.
- The branch is moved to the new commit: local copies need a `git pull --rebase` or a reset.

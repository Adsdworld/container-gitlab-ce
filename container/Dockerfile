# GitLab CE with the changes of this fork: several reviewers per merge request, precommit
# pipelines and hidden files in merge request diffs.
#
# The changes are a patch on the gitlab-rails of an official image, not a build from source. The
# base tag must be close to the imported upstream (see VERSION), otherwise the patch does not apply.
ARG GITLAB_TAG=nightly
FROM gitlab/gitlab-ce:${GITLAB_TAG}

ARG IMAGE_VERSION=dev
ENV IMAGE_VERSION=$IMAGE_VERSION

RUN apt-get update \
 && apt-get install -y --no-install-recommends patch \
 && rm -rf /var/lib/apt/lists/*

COPY fork.patch /tmp/fork.patch
# --forward: refuse to reverse a patch already applied; the build fails on any rejected hunk.
RUN cd /opt/gitlab/embedded/service/gitlab-rails \
 && patch -p1 --forward --no-backup-if-mismatch --fuzz=2 < /tmp/fork.patch \
 && rm /tmp/fork.patch

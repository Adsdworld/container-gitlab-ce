# frozen_string_literal: true

module Graphify
  # Replaces the head commit of a merge request source branch by the same commit with
  # an up to date graphify-out/. Opt-in per project: the repository holds a
  # `.gitlab-graphify` file at its root.
  class RewriteCommitService
    CONFIG_FILE = '.gitlab-graphify'
    TMP_BRANCH_PREFIX = 'graphify-tmp/'
    TMP_COMMIT_MESSAGE = "graphify-out\n\n[ci skip]"

    def initialize(project, user, branch:, sha:)
      @project = project
      @user = user
      @branch = branch
      @sha = sha
    end

    # @return [Symbol] :skipped, :up_to_date or :rewritten
    def execute
      return :skipped unless eligible?

      actions = Gitlab::Graphify::Builder.new(repository, sha).execute.filter_map { |path, content| action_for(path, content) }
      return :up_to_date if actions.empty?

      rewrite(actions)
    end

    private

    attr_reader :project, :user, :branch, :sha

    def repository
      project.repository
    end

    def eligible?
      return false unless Gitlab::Graphify::Builder.available?
      return false if branch == project.default_branch
      return false unless head_commit && head_commit.parent_ids.one?
      return false unless repository.blob_exists_at?(sha, CONFIG_FILE)

      repository.find_branch(branch)&.target == sha && open_merge_request?
    end

    def head_commit
      @head_commit ||= repository.commit(sha)
    end

    def open_merge_request?
      project.source_of_merge_requests.opened.where(source_branch: branch).exists?
    end

    def action_for(path, content)
      current = repository.blob_at(sha, path)
      return if current && current.data == content

      { action: current ? :update : :create, file_path: path, content: content }
    end

    def rewrite(actions)
      tmp_branch = "#{TMP_BRANCH_PREFIX}#{sha}"

      child = repository.commit_files(
        user, branch_name: tmp_branch, message: TMP_COMMIT_MESSAGE, actions: actions,
        start_sha: sha, skip_target_sha: true, sign: false)

      squashed = repository.squash_commits_as(
        user, author: author, start_sha: head_commit.parent_ids.first, end_sha: child, message: head_commit.message)

      repository.raw_repository.update_branch(branch, user: user, newrev: squashed, oldrev: sha)
      repository.expire_branches_cache

      :rewritten
    ensure
      remove_tmp_branch(tmp_branch)
    end

    def remove_tmp_branch(tmp_branch)
      return unless tmp_branch && repository.find_branch(tmp_branch)

      repository.rm_branch(user, tmp_branch)
    end

    # The squash needs a GitLab user as author: the one of the commit when its email
    # is known, the pusher otherwise.
    def author
      User.find_by_any_email(head_commit.author_email) || user
    end
  end
end

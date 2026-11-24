# frozen_string_literal: true

module Ci
  module Precommit
    # Replaces the head commit of a branch by the same commit with the given files added.
    # Gitaly cannot amend, so a child commit with the files is made on a temporary branch, then
    # squashed onto the parent of the head commit: same parent, same message, same changes plus
    # the files. The author is the GitLab user of the commit email, the pusher otherwise.
    class AmendCommitService
      TMP_BRANCH_PREFIX = 'precommit-tmp/'
      TMP_COMMIT_MESSAGE = "precommit artifacts\n\n[ci skip]"

      Error = Class.new(StandardError)

      def initialize(project, user, branch:, sha:, files:)
        @project = project
        @user = user
        @branch = branch
        @sha = sha
        @files = files
      end

      # @return [Symbol] :unchanged when the commit already holds the files, :amended otherwise
      def execute
        raise Error, 'the branch moved or the commit cannot be amended' unless amendable?

        actions = build_actions
        return :unchanged if actions.empty?

        amend(actions)
        :amended
      end

      private

      attr_reader :project, :user, :branch, :sha, :files

      def repository
        project.repository
      end

      def head_commit
        @head_commit ||= repository.commit(sha)
      end

      def amendable?
        head_commit && head_commit.parent_ids.one? && repository.find_branch(branch)&.target == sha
      end

      def build_actions
        files.filter_map do |path, content|
          current = repository.blob_at(sha, path)
          next if current && current.data == content

          { action: current ? :update : :create, file_path: path, content: content }
        end
      end

      def amend(actions)
        tmp_branch = "#{TMP_BRANCH_PREFIX}#{sha}"
        remove_tmp_branch(tmp_branch)

        child = repository.commit_files(
          user, branch_name: tmp_branch, message: TMP_COMMIT_MESSAGE, actions: actions, start_sha: sha)
        raise Error, 'could not create the commit with the artifacts' if child.blank?

        squashed = repository.squash_commits_as(
          user, author: author, start_sha: head_commit.parent_ids.first, end_sha: child, message: head_commit.message)

        # Marked first: the push of the amended commit must not start another precommit pipeline.
        Marker.mark!(project, squashed)
        repository.raw_repository.update_branch(branch, user: user, newrev: squashed, oldrev: sha)
        repository.expire_branches_cache
      ensure
        begin
          remove_tmp_branch(tmp_branch)
        rescue StandardError => e
          Gitlab::ErrorTracking.track_exception(e, project_id: project.id, branch: tmp_branch)
        end
      end

      def remove_tmp_branch(tmp_branch)
        return unless repository.find_branch(tmp_branch)

        repository.rm_branch(user, tmp_branch)
      end

      def author
        User.find_by_any_email(head_commit.author_email) || user
      end
    end
  end
end

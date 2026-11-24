# frozen_string_literal: true

module Ci
  module Precommit
    # Runs when a precommit pipeline is over. On success, the artifacts it produced under the
    # commit_paths of gitlab-precommit.yaml are added to the head commit. In every other case, or
    # when there is nothing to add, the regular pipeline of the push is created on the commit as it was.
    class ApplyService
      def initialize(pipeline)
        @pipeline = pipeline
        @project = pipeline.project
        @user = pipeline.user
        @branch = pipeline.ref
        @sha = pipeline.sha
      end

      def execute
        return unless user && branch_head_is_pipeline_sha?
        return if pipeline.success? && amend

        RegularPipelineService.new(project, user, branch: branch, sha: sha, before_sha: pipeline.before_sha).execute
      end

      private

      attr_reader :pipeline, :project, :user, :branch, :sha

      def branch_head_is_pipeline_sha?
        project.repository.find_branch(branch)&.target == sha
      end

      # @return [Boolean] whether the branch now points to an amended commit
      def amend
        config = Eligibility.new(project, branch: branch, sha: sha).config
        return false unless config

        files = ArtifactFiles.new(pipeline, config).execute
        return false if files.empty?

        AmendCommitService.new(project, user, branch: branch, sha: sha, files: files).execute == :amended
      rescue ArtifactFiles::Error, AmendCommitService::Error, Gitlab::Git::PreReceiveError,
        Gitlab::Git::CommandError, Gitlab::Git::CommitError => e
        Gitlab::AppLogger.warn(
          message: 'Precommit artifacts not applied', error: e.message, project_id: project.id,
          pipeline_id: pipeline.id, branch: branch)
        false
      end
    end
  end
end

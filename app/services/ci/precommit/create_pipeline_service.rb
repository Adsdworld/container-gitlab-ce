# frozen_string_literal: true

module Ci
  module Precommit
    # Starts the precommit pipeline of a pushed commit, with the jobs of gitlab-precommit.yaml.
    # When there is nothing to run, the regular pipeline is created instead.
    class CreatePipelineService
      def initialize(project, user, branch:, sha:, before_sha:, pipeline_creation_request: nil)
        @project = project
        @user = user
        @branch = branch
        @sha = sha
        @before_sha = before_sha
        @pipeline_creation_request = pipeline_creation_request
      end

      # @return [Ci::Pipeline, nil] the precommit pipeline, nil when none was started
      def execute
        return unless head_unchanged?

        config = Eligibility.new(project, branch: branch, sha: sha).then { |eligibility| eligibility.config if eligibility.eligible? }
        return regular_pipeline unless config

        pipeline = create(config)
        return pipeline if pipeline&.created_successfully? && pipeline.persisted?

        regular_pipeline
      end

      private

      attr_reader :project, :user, :branch, :sha, :before_sha, :pipeline_creation_request

      def head_unchanged?
        project.repository.find_branch(branch)&.target == sha
      end

      def create(config)
        ref = "#{Gitlab::Git::BRANCH_REF_PREFIX}#{branch}"

        Ci::CreatePipelineService
          .new(project, user, before: before_sha, after: sha, ref: ref, checkout_sha: sha)
          .execute(:precommit, ignore_skip_ci: true, save_on_errors: false, content: config.jobs_yaml)
          .payload
      end

      def regular_pipeline
        RegularPipelineService.new(
          project, user, branch: branch, sha: sha, before_sha: before_sha,
          pipeline_creation_request: pipeline_creation_request).execute
        nil
      end
    end
  end
end

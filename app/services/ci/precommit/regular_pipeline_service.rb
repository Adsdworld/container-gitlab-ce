# frozen_string_literal: true

module Ci
  module Precommit
    # The pipeline a push would have had, created once the precommit step is over.
    class RegularPipelineService
      def initialize(project, user, branch:, sha:, before_sha:, pipeline_creation_request: nil)
        @project = project
        @user = user
        @branch = branch
        @sha = sha
        @before_sha = before_sha
        @pipeline_creation_request = pipeline_creation_request
      end

      def execute
        ref = "#{Gitlab::Git::BRANCH_REF_PREFIX}#{branch}"

        Ci::CreatePipelineService
          .new(project, user, before: before_sha, after: sha, ref: ref,
            checkout_sha: Gitlab::DataBuilder::Push.checkout_sha(project.repository, sha, ref),
            pipeline_creation_request: pipeline_creation_request)
          .execute(:push)
      end

      private

      attr_reader :project, :user, :branch, :sha, :before_sha, :pipeline_creation_request
    end
  end
end

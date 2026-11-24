# frozen_string_literal: true

module Ci
  module Precommit
    class CreatePipelineWorker
      include ApplicationWorker

      data_consistency :sticky
      idempotent!
      deduplicate :until_executing
      feature_category :continuous_integration
      urgency :low

      def perform(project_id, user_id, branch, sha, before_sha, pipeline_creation_request = nil)
        project = Project.find_by_id(project_id)
        user = User.find_by_id(user_id)
        return unless project && user

        Ci::Precommit::CreatePipelineService.new(
          project, user, branch: branch, sha: sha, before_sha: before_sha,
          pipeline_creation_request: pipeline_creation_request).execute
      end
    end
  end
end

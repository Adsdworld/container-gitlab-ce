# frozen_string_literal: true

class GraphifyRewriteWorker
  include ApplicationWorker
  include ExclusiveLeaseGuard

  data_consistency :sticky
  idempotent!
  deduplicate :until_executing
  sidekiq_options retry: 1
  feature_category :source_code_management
  urgency :low
  worker_has_external_dependencies!

  LEASE_TIMEOUT = 20.minutes

  attr_reader :project, :branch

  def perform(project_id, user_id, branch, sha)
    @project = Project.find_by_id(project_id)
    user = User.find_by_id(user_id)
    return unless project && user

    @branch = branch

    try_obtain_lease do
      Graphify::RewriteCommitService.new(project, user, branch: branch, sha: sha).execute
    end
  rescue Gitlab::Graphify::Builder::Error, Gitlab::Git::CommandError, Gitlab::Git::PreReceiveError => e
    Gitlab::ErrorTracking.track_exception(e, project_id: project_id, branch: branch)
  end

  private

  def lease_timeout
    LEASE_TIMEOUT
  end

  def lease_key
    "gitlab:graphify_rewrite:#{project.id}:#{Digest::SHA256.hexdigest(branch)}"
  end
end

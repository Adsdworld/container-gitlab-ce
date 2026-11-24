# frozen_string_literal: true

module Ci
  module Precommit
    # Whether a push to a branch gets a precommit pipeline: the branch is the source of an open
    # merge request of the same project, and the gitlab-precommit.yaml of that request target
    # branch is present and enabled. The file is read on the target branch, never on the
    # pushed one, so a merge request cannot change what it is allowed to write.
    class Eligibility
      def initialize(project, branch:, sha:)
        @project = project
        @branch = branch
        @sha = sha
      end

      def eligible?
        return false if branch == project.default_branch
        return false if sha.blank? || Marker.marked?(project, sha)
        return false unless single_parent?

        config.present?
      end

      # @return [Gitlab::Precommit::Config, nil]
      def config
        return @config if defined?(@config)

        @config = target_branches.lazy.filter_map do |target_branch|
          target_sha = project.repository.commit(target_branch)&.sha
          candidate = Gitlab::Precommit::Config.new(project, target_sha) if target_sha
          candidate if candidate&.enabled?
        end.first
      end

      private

      attr_reader :project, :branch, :sha

      def target_branches
        project.source_of_merge_requests.opened.where(source_branch: branch).distinct.pluck(:target_branch)
      end

      def single_parent?
        project.repository.commit(sha)&.parent_ids&.one? || false
      end
    end
  end
end

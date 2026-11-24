# frozen_string_literal: true

module Ci
  module Precommit
    # Remembers the commits made by the precommit amend, so the push that follows is not
    # given another precommit pipeline.
    class Marker
      TTL = 1.day.to_i

      def self.mark!(project, sha)
        Gitlab::Redis::SharedState.with { |redis| redis.set(key(project, sha), '1', ex: TTL) }
      end

      def self.marked?(project, sha)
        Gitlab::Redis::SharedState.with { |redis| redis.get(key(project, sha)).present? }
      end

      def self.key(project, sha)
        "gitlab:ci:precommit:amended:#{project.id}:#{sha}"
      end
    end
  end
end

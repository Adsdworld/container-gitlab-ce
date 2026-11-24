# frozen_string_literal: true

module Ci
  module Precommit
    # rubocop: disable Scalability/IdempotentWorker -- EventStore::Subscriber includes idempotent
    class ApplyArtifactsWorker
      include Gitlab::EventStore::Subscriber

      feature_category :continuous_integration
      data_consistency :sticky

      def handle_event(event)
        pipeline = Ci::Pipeline.find_by_id_and_partition(event.data[:pipeline_id], event.data[:partition_id])
        return unless pipeline && pipeline.source == 'precommit'

        Ci::Precommit::ApplyService.new(pipeline).execute
      end
    end
    # rubocop: enable Scalability/IdempotentWorker
  end
end

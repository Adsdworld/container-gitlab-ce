# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::Precommit::Marker, :clean_gitlab_redis_shared_state, feature_category: :continuous_integration do
  let_it_be(:project) { create(:project) }

  it 'remembers a marked sha only' do
    described_class.mark!(project, 'a' * 40)

    expect(described_class.marked?(project, 'a' * 40)).to be(true)
    expect(described_class.marked?(project, 'b' * 40)).to be(false)
  end
end

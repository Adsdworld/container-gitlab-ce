# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Precommit::Config, feature_category: :continuous_integration do
  let_it_be(:project) { create(:project, :repository) }

  let(:sha) { project.repository.commit.sha }
  let(:content) { nil }

  subject(:config) { described_class.new(project, sha) }

  before do
    allow(project.repository).to receive(:blob_at).with(sha, described_class::FILE_NAME, limit: anything)
      .and_return(content && instance_double(Blob, data: content, size: content.bytesize))
  end

  context 'without the file' do
    it { is_expected.not_to be_present }
    it { is_expected.not_to be_enabled }
  end

  context 'with a valid file' do
    let(:content) do
      <<~YAML
        precommit:
          commit_paths: [graphify-out/]
          hide_in_ui: [graphify-out/]
        graphify:
          script: [graphify-build]
      YAML
    end

    it 'is enabled and splits the reserved block from the jobs' do
      expect(config).to be_enabled
      expect(config.commit_paths).to eq(['graphify-out/'])
      expect(config.hide_in_ui).to eq(['graphify-out/'])
      expect(YAML.safe_load(config.jobs_yaml).keys).to eq(['graphify'])
    end

    it 'accepts only the files under commit_paths' do
      expect(config.commit_path?('graphify-out/graph.json')).to be(true)
      expect(config.commit_path?('app/models/user.rb')).to be(false)
    end
  end

  context 'with enabled set to false' do
    let(:content) { "precommit:\n  enabled: false\n  commit_paths: [out/]\n" }

    it { is_expected.not_to be_enabled }
  end

  context 'with an unknown key in the precommit block' do
    let(:content) { "precommit:\n  commit_paths: [out/]\n  command: rm -rf /\n" }

    it { is_expected.not_to be_enabled }
  end

  context 'with commit_paths pointing to a protected place' do
    %w[.gitlab-ci.yml .github/workflows ../etc .git/hooks /abs gitlab-precommit.yaml].each do |path|
      it "rejects #{path}" do
        allow(project.repository).to receive(:blob_at).with(sha, described_class::FILE_NAME, limit: anything)
          .and_return(instance_double(Blob, data: "precommit:\n  commit_paths: ['#{path}']\n", size: 60))

        expect(described_class.new(project, sha)).not_to be_enabled
      end
    end
  end
end

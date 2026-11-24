# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Diff::UiIgnore, feature_category: :code_review_workflow do
  subject(:ui_ignore) { described_class.new(content) }

  describe '#ignored?' do
    where(:content, :path, :expected) do
      "graphify-out/\n"      | 'graphify-out/graph.json'     | true
      "graphify-out/\n"      | 'a/graphify-out/graph.json'   | true
      "graphify-out/\n"      | 'graphify-outer/graph.json'   | false
      "/graphify-out\n"      | 'graphify-out/graph.json'     | true
      "/graphify-out\n"      | 'a/graphify-out/graph.json'   | false
      "*.lock\n"             | 'a/b/yarn.lock'               | true
      "docs/**/*.md\n"       | 'docs/a/b/c.md'               | true
      "docs/**/*.md\n"       | 'docs/c.md'                   | true
      "docs/**/*.md\n"       | 'other/c.md'                  | false
      "a.b\n"                | 'axb'                         | false
      "# graphify-out/\n"    | 'graphify-out/graph.json'     | false
      "!graphify-out/\n"     | 'graphify-out/graph.json'     | false
      ''                     | 'graphify-out/graph.json'     | false
    end

    with_them do
      it { expect(ui_ignore.ignored?(path)).to eq(expected) }
    end

    context 'without a path' do
      let(:content) { "*\n" }

      it { expect(ui_ignore.ignored?(nil)).to be(false) }
    end
  end

  describe '#empty?' do
    it 'is true without any pattern' do
      expect(described_class.new("# nothing\n\n")).to be_empty
    end
  end

  describe '.from_patterns' do
    it 'hides the files matching a pattern' do
      ui_ignore = described_class.from_patterns(['graphify-out/', '*.lock'])

      expect(ui_ignore.ignored?('graphify-out/graph.json')).to be(true)
      expect(ui_ignore.ignored?('yarn.lock')).to be(true)
      expect(ui_ignore.ignored?('app/models/user.rb')).to be(false)
    end
  end

  describe '.for_merge_request' do
    let_it_be(:project) { create(:project, :repository) }
    let(:merge_request) { build_stubbed(:merge_request, source_project: project, target_project: project) }

    it 'is empty when the target branch has no gitlab-precommit.yaml' do
      expect(described_class.for_merge_request(merge_request)).to be_empty
    end

    it 'uses the hide_in_ui patterns of the target branch' do
      config = instance_double(Gitlab::Precommit::Config, enabled?: true, hide_in_ui: ['graphify-out/'])
      allow(Gitlab::Precommit::Config).to receive(:new).and_return(config)

      expect(described_class.for_merge_request(merge_request).ignored?('graphify-out/graph.json')).to be(true)
    end
  end
end

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

  describe '.for' do
    let_it_be(:project) { create(:project, :repository) }

    it 'is empty without a sha' do
      expect(described_class.for(project.repository, nil)).to be_empty
    end

    it 'is empty when the file does not exist' do
      expect(described_class.for(project.repository, project.commit.sha)).to be_empty
    end
  end
end

# frozen_string_literal: true

module Gitlab
  module Diff
    # Paths hidden from the merge request diffs: the `hide_in_ui` patterns of the
    # gitlab-precommit.yaml of the merge request target branch. As in a `.gitignore`: `*`, `?`
    # and `**`, a leading or inner `/` anchors the pattern, a trailing `/` matches a directory.
    # Lines starting with `#` or `!` are ignored: negations are not supported.
    class UiIgnore
      def self.empty
        new('')
      end

      def self.from_patterns(patterns)
        new(Array(patterns).join("\n"))
      end

      def self.for_merge_request(merge_request)
        sha = merge_request.target_branch_sha
        return empty if sha.blank?

        config = Gitlab::Precommit::Config.new(merge_request.target_project, sha)
        config.enabled? ? from_patterns(config.hide_in_ui) : empty
      end

      def initialize(content)
        @rules = content.lines.filter_map { |line| compile(line.strip) }
      end

      def empty?
        @rules.empty?
      end

      def ignored?(path)
        path.present? && @rules.any? { |rule| rule.match?(path) }
      end

      private

      def compile(line)
        return if line.empty? || line.start_with?('#', '!')

        directory = line.end_with?('/')
        pattern = line.delete_suffix('/')
        anchored = pattern.start_with?('/') || pattern.include?('/')
        pattern = pattern.delete_prefix('/')

        head = anchored ? '\A' : '\A(?:.*/)?'
        tail = directory ? '/.*\z' : '(?:/.*)?\z'

        Regexp.new("#{head}#{translate(pattern)}#{tail}")
      end

      def translate(glob)
        glob.gsub(%r{\*\*/|\*\*|\*|\?|[^*?]+}) do |token|
          case token
          when '**/' then '(?:.*/)?'
          when '**' then '.*'
          when '*' then '[^/]*'
          when '?' then '[^/]'
          else Regexp.escape(token)
          end
        end
      end
    end
  end
end

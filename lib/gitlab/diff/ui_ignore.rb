# frozen_string_literal: true

module Gitlab
  module Diff
    # Paths hidden from the merge request diffs, from the `.gitlab-ui-ignore` file of the
    # target branch. One pattern per line, as in a `.gitignore`: `#` comments, `*`, `?`
    # and `**`, a leading or inner `/` anchors the pattern, a trailing `/` matches a
    # directory. Negations (`!`) are not supported.
    class UiIgnore
      FILE = '.gitlab-ui-ignore'

      def self.for(repository, sha)
        return new('') if sha.blank?

        new(repository.blob_data_at(sha, FILE).to_s.dup.force_encoding(Encoding::UTF_8).scrub)
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

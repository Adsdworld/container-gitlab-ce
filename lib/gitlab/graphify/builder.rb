# frozen_string_literal: true

require 'rubygems/package'

module Gitlab
  module Graphify
    # Builds the graphify-out/ files of a commit, from a copy of its tree and with the
    # graphify installed on the instance (GITLAB_GRAPHIFY_BIN). The same code gives the
    # same files.
    class Builder
      Error = Class.new(StandardError)

      OUTPUT_DIR = 'graphify-out'
      OUTPUT_FILES = %w[graph.json GRAPH_REPORT.md graph.html].freeze
      MAX_TREE_BYTES = 512.megabytes
      TIMEOUT_SECONDS = 900

      def self.binary
        ENV['GITLAB_GRAPHIFY_BIN'].presence
      end

      def self.available?
        binary.present?
      end

      def initialize(repository, sha)
        @repository = repository
        @sha = sha
      end

      # @return [Hash{String => String}] repository path => content
      def execute
        raise Error, 'GITLAB_GRAPHIFY_BIN is not set' unless self.class.available?

        Dir.mktmpdir('graphify') do |dir|
          extract_tree(dir)
          build(dir)
          read_output(dir)
        end
      end

      private

      attr_reader :repository, :sha

      def extract_tree(dir)
        Tempfile.create('graphify-tree') do |archive|
          archive.binmode
          repository.raw_repository.archive_tar(sha, exclude: [OUTPUT_DIR]) { |chunk| archive.write(chunk) }
          archive.flush
          archive.rewind

          write_entries(archive, dir)
        end
      end

      def write_entries(archive, dir)
        root = File.realpath(dir)
        total = 0

        Gem::Package::TarReader.new(archive).each do |entry|
          next unless entry.file?

          path = File.expand_path(entry.full_name, root)
          raise Error, "unsafe path in archive: #{entry.full_name}" unless path.start_with?("#{root}/")

          total += entry.header.size
          raise Error, 'tree is too large' if total > MAX_TREE_BYTES

          FileUtils.mkdir_p(File.dirname(path))
          File.binwrite(path, entry.read)
        end
      end

      def build(dir)
        env = { 'GRAPHIFY_BACKEND' => 'none', 'HOME' => dir }

        [%w[extract . --code-only], %w[cluster-only .]].each do |args|
          output, status = Gitlab::Popen.popen(
            ['timeout', TIMEOUT_SECONDS.to_s, self.class.binary, *args], dir, env)

          raise Error, "graphify #{args.first} failed: #{output.to_s.last(500)}" unless status == 0
        end
      end

      def read_output(dir)
        OUTPUT_FILES.to_h do |name|
          file = File.join(dir, OUTPUT_DIR, name)
          raise Error, "graphify did not write #{name}" unless File.file?(file)

          ["#{OUTPUT_DIR}/#{name}", File.binread(file)]
        end
      end
    end
  end
end

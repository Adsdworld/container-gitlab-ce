# frozen_string_literal: true

module Ci
  module Precommit
    # The files the jobs of a precommit pipeline want in the commit, read out of their artifacts
    # archives. Artifacts are untrusted: any job of the pipeline, on any runner, wrote them.
    # Everything that is not clearly a regular file under commit_paths fails the whole run.
    class ArtifactFiles
      Error = Class.new(StandardError)

      MAX_ARCHIVE_BYTES = 20.megabytes
      MAX_ENTRIES = 1_000
      MAX_FILE_BYTES = 10.megabytes
      MAX_TOTAL_BYTES = 50.megabytes

      def initialize(pipeline, config)
        @pipeline = pipeline
        @config = config
        @files = {}
        @total_bytes = 0
      end

      # @return [Hash{String => String}] repository path => content, sorted by path
      def execute
        pipeline.latest_builds.success.each { |build| read_build(build) }

        files.sort.to_h
      end

      private

      attr_reader :pipeline, :config, :files

      def read_build(build)
        return unless build.available_artifacts?
        raise Error, "artifacts of #{build.name} are too large" if build.artifacts_size.to_i > MAX_ARCHIVE_BYTES

        build.artifacts_file.use_open_file do |file|
          zip = Zip::File.open_buffer(file)
          raise Error, "artifacts of #{build.name} have too many entries" if zip.size > MAX_ENTRIES

          zip.each { |entry| read_entry(build, entry) }
        end
      rescue Zip::Error, Zlib::Error => e
        raise Error, "artifacts of #{build.name} are unreadable: #{e.class}"
      end

      def read_entry(build, entry)
        name = entry.name.to_s.unicode_normalize(:nfc).delete_prefix('./')
        raise Error, "unsafe artifact path in #{build.name}" if unsafe?(name)
        return unless config.commit_path?(name)
        return if entry.directory?
        raise Error, "#{name} from #{build.name} is not a regular file" unless entry.ftype == :file

        store(name, build, read_bounded(entry))
      end

      def unsafe?(name)
        name.start_with?('/') || !Gitlab::Ci::Build::Artifacts::Path.new(name).valid? ||
          Gitlab::PathTraversal.path_traversal?(name)
      end

      def read_bounded(entry)
        data = entry.get_input_stream { |stream| stream.read(MAX_FILE_BYTES + 1) }.to_s
        raise Error, "#{entry.name} is larger than #{MAX_FILE_BYTES} bytes" if data.bytesize > MAX_FILE_BYTES

        data
      end

      def store(name, build, data)
        existing = files[name]
        raise Error, "#{name} is written by two jobs (#{build.name} and another one)" if existing && existing != data
        return if existing

        @total_bytes += data.bytesize
        raise Error, 'artifacts are larger than the total limit' if @total_bytes > MAX_TOTAL_BYTES

        files[name] = data
      end
    end
  end
end

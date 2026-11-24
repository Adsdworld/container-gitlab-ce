# frozen_string_literal: true

module Gitlab
  module Precommit
    # The gitlab-precommit.yaml of a project at a given sha. It holds CI jobs, run before the
    # regular pipeline, and a reserved `precommit:` block that the CI parser never sees.
    class Config
      include ActiveModel::Validations

      FILE_NAME = 'gitlab-precommit.yaml'
      BLOCK_KEY = 'precommit'
      CACHE_EXPIRY = 5.minutes
      # Never written by a precommit job, whatever commit_paths says. Compared in lower case.
      DENIED_PATHS = %w[
        .gitlab-ci.yml gitlab-precommit.yaml .gitattributes .gitmodules .gitignore codeowners
        .gitlab .github docs/codeowners
      ].freeze

      attr_reader :project, :sha, :precommit_block

      # @param sha [String] revision of the file, the head of the merge request target branch
      def initialize(project, sha)
        @project = project
        @sha = sha
        @config = load_config
        @precommit_block = @config.fetch(BLOCK_KEY, {})
        @precommit_block = {} unless @precommit_block.is_a?(Hash)
      end

      # The file exists, is readable YAML and not switched off.
      def enabled?
        present? && precommit_block.fetch('enabled', true) == true && valid?
      end

      def present?
        @config.present?
      end

      def valid?
        super
        run_schema_validation
        errors.empty? && commit_paths.all? { |path| safe_prefix?(path) }
      end

      def error_message
        valid?
        errors.full_messages.to_sentence.presence || 'commit_paths must be relative paths without ".."'
      end

      def commit_paths
        Array(precommit_block['commit_paths']).map { |path| normalize(path) }
      end

      def hide_in_ui
        Array(precommit_block['hide_in_ui']).map(&:to_s)
      end

      # The jobs, as YAML for Ci::CreatePipelineService, without the reserved block.
      def jobs_yaml
        @config.except(BLOCK_KEY).to_yaml
      end

      # Whether a precommit job may write this repository path.
      def commit_path?(path)
        return false if path.blank? || denied?(path)

        commit_paths.any? { |prefix| path == prefix || path.start_with?("#{prefix.delete_suffix('/')}/") }
      end

      def cache_key
        "precommit_config:#{project.id}:#{sha}"
      end

      private

      def load_config
        return {} if sha.blank? || project.empty_repo?

        Rails.cache.fetch(cache_key, expires_in: CACHE_EXPIRY) { read_file }
      end

      def read_file
        limit = Gitlab::CurrentSettings.max_yaml_size_bytes
        blob = project.repository.blob_at(sha, FILE_NAME, limit: limit)
        return {} if blob.nil? || blob.size > limit

        ::Gitlab::Config::Loader::Yaml.new(blob.data).load_raw!
      rescue ::Gitlab::Config::Loader::Yaml::NotHashError, ::Gitlab::Config::Loader::FormatError
        {}
      end

      def normalize(path)
        path.to_s.strip.delete_prefix('./')
      end

      def safe_prefix?(path)
        path.present? && !path.start_with?('/') && !Gitlab::PathTraversal.path_traversal?(path) && !denied?(path)
      end

      def denied?(path)
        components = path.downcase.split('/')
        components.include?('.git') || DENIED_PATHS.include?(path.downcase.delete_suffix('/')) ||
          DENIED_PATHS.include?(components.first)
      end

      def run_schema_validation
        JsonSchemaValidator.new(
          filename: 'precommit', attributes: [:precommit_block], detail_errors: true
        ).validate(self)
      end
    end
  end
end

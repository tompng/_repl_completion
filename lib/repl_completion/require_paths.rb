# frozen_string_literal: true

module ReplCompletion
  module RequirePaths
    class << self
      def require_completions(target_path)
        *dir, target = target_path.split('/', -1)
        target ||= ''
        paths = with_cache [:require_completions, dir] do
          gem_and_system_load_paths.flat_map do |load_path|
            base_dir = File.absolute_path(File.join(load_path, *dir))
            with_cache [:requireable_paths, base_dir] do
              requireable_paths(base_dir)
            end
          end.sort
        end
        paths.filter_map do |path|
          [*dir, path].join('/') if path.start_with?(target)
        end
      end

      def require_relative_completions(target_path, binding)
        current_filepath = binding.source_location[0]
        *dir, target = target_path.split('/', -1)
        target ||= ''
        base_dir = File.absolute_path(File.join(File.dirname(current_filepath), *dir))
        paths = with_cache [:requireable_paths, base_dir] do
          requireable_paths(base_dir)
        end
        paths.filter_map do |path|
          [*dir, path].join('/') if path.start_with?(target)
        end
      end

      private

      def with_cache(key)
        @cache ||= {}
        @cache[key] ||= yield
      end

      def gem_paths
        return [] unless defined?(Gem::Specification)

        Gem::Specification.latest_specs(true).flat_map do |spec|
          spec.require_paths.map do |path|
            File.absolute_path?(path) ? path : File.join(spec.full_gem_path, path)
          end
        end
      end

      def gem_and_system_load_paths
        @gem_and_system_load_paths ||= (gem_paths | $LOAD_PATH).filter_map do |path|
          if path.respond_to?(:to_path)
            path.to_path
          else
            String(path) rescue nil
          end
        end.sort
      end

      def requireable_paths(base_dir)
        ext = ".{rb,#{RbConfig::CONFIG['DLEXT']}}"
        ext_regexp = /\.(rb|#{RbConfig::CONFIG['DLEXT']})\z/
        files = Dir.glob(["*#{ext}", "*/*#{ext}"], base: base_dir).map { |p| p.sub(ext_regexp, '') }
        dirs = Dir.glob('*/*', base: base_dir).filter_map do |path|
          "#{path}/" if File.directory?(File.join(base_dir, path))
        end
        (files + dirs).sort
      rescue Errno::EPERM
        []
      end
    end
  end
end

# frozen_string_literal: true

def common_dir
  @common_dir ||= Gem::Specification.find_by_name("dependabot-common").gem_dir
end

def require_common_spec(path)
  require "#{common_dir}/spec/dependabot/#{path}"
end

require "#{common_dir}/spec/spec_helper.rb"

module PackageManagerHelper
  # TODO: Make bundler 2 the default if no `SUITE_NAME` is set
  def self.use_bundler_1?
    !use_bundler_2?
  end

  def self.use_bundler_2?
    ENV["SUITE_NAME"] == "bundler2"
  end

  def self.bundler_version
    use_bundler_2? ? "2" : "1"
  end
end

# Move the existing fixture method aside so we can shim in a check for old-style manifest fixtures
alias non_project_fixture fixture

def fixture(*name)
  if PackageManagerHelper.use_bundler_2? && name.any? { |folder| %w(gemfiles gemspecs lockfiles).include? folder }
    raise "Non-Project Fixture Loaded: '#{File.join(name)}'."
  end

  non_project_fixture(*name)
end

def bundler_project_dependency_files(project)
  project_dependency_files(File.join("bundler#{PackageManagerHelper.bundler_version}", project))

  # TODO: Remove this before merging!
rescue StandardError
  if PackageManagerHelper.use_bundler_2? && !ENV["CI"]
    FileUtils.copy_entry File.join("spec/fixtures/projects/bundler1", project),
                         File.join("spec/fixtures/projects/bundler2", project)
  end

  raise
end

def bundler_project_dependency_file(project, filename:)
  dependency_file = bundler_project_dependency_files(project).find{ |file| file.name == filename }

  raise "Dependency File '#{filename} does not exist for project '#{project}'" unless dependency_file

  dependency_file
end

RSpec.configure do |config|
  config.around do |example|
    if PackageManagerHelper.use_bundler_2? && example.metadata[:bundler_v1_only]
      example.skip
    elsif PackageManagerHelper.use_bundler_1? && example.metadata[:bundler_v2_only]
      example.skip
    else
      example.run
    end
  end
end

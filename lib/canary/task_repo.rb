require "yaml"

module Canary
  # Loads tasks/** into Canary::Task pairs that Pool#rollout_task already
  # accepts. A loader, not a framework: one directory per task, meta.yml for
  # what a directory listing can't say (category, adapter, statement), fixed
  # filenames (grader.rb, solution.rb, broken_solution.rb) for everything
  # else.
  class TaskRepo
    ROOT = File.expand_path("../../tasks", __dir__)

    Entry = Struct.new(:name, :category, :statement, :adapter, :reference, :broken, keyword_init: true)

    def self.all(root: ROOT)
      new(root).all
    end

    def initialize(root = ROOT)
      @root = root
    end

    def all
      Dir.children(@root).sort.select { |name| File.directory?(File.join(@root, name)) }.map { |name| load_task(name) }
    end

    private

    def load_task(name)
      dir = File.join(@root, name)
      meta = YAML.load_file(File.join(dir, "meta.yml"), symbolize_names: true)
      adapter = meta.fetch(:adapter).to_sym
      test_path = File.join(dir, "grader.rb")

      Entry.new(
        name: name,
        category: meta.fetch(:category),
        statement: meta.fetch(:statement),
        adapter: adapter,
        reference: Task.new(solution_path: File.join(dir, "solution.rb"), test_path: test_path, adapter: adapter),
        broken: Task.new(solution_path: File.join(dir, "broken_solution.rb"), test_path: test_path, adapter: adapter)
      )
    end
  end
end

require "yaml"

module Canary
  # Loads tasks/** into Canary::Task pairs that Pool#rollout_task already
  # accepts. A loader, not a framework: one directory per task, meta.yml for
  # what a directory listing can't say (category, adapter, statement,
  # provenance, the id/misconception of each broken solution), fixed
  # filenames (grader.rb, solution.rb, broken/<id>.rb) for everything else.
  class TaskRepo
    ROOT = File.expand_path("../../tasks", __dir__)

    # +provenance+ is "authored" (written for this project) or "sourced"
    # (adapted from an external corpus). +source_attestation+ is the
    # training-data cutoff attestation a sourced task must carry - nil for
    # an authored one, since there's nothing to attest to.
    #
    # Both are real members of the Data class (Entry.members includes them),
    # so exhaustive per-field reflection elsewhere (prompt_test.rb's
    # test_hidden_mode_leaks_no_entry_field_other_than_statement) sees them
    # like any other field. The custom #initialize defaults provenance:
    # "authored" and source_attestation: nil when a caller doesn't pass
    # them, and nils out category/adapter/broken_solutions when omitted too
    # (Data.define has no equivalent to Struct's free keyword_init nil-fill -
    # several tests build a fixture Entry with only name/statement/reference),
    # so every existing Entry.new call site - #load_task below and every test
    # that builds a partial Entry - keeps working unmodified.
    Entry = Data.define(:name, :category, :statement, :adapter, :reference, :broken_solutions, :provenance, :source_attestation) do
      def initialize(category: nil, adapter: nil, broken_solutions: nil, provenance: "authored", source_attestation: nil, **rest)
        super(category: category, adapter: adapter, broken_solutions: broken_solutions, provenance: provenance, source_attestation: source_attestation, **rest)
      end
    end

    # +misconception+ is a free-text description of the plausible mistake
    # this solution embodies - documentation, not a score (BRIEF §6.1 is
    # unresolved; this corpus carries no numeric difficulty or weight).
    BrokenSolution = Data.define(:id, :misconception, :task)

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
      provenance = meta.fetch(:provenance)
      source_attestation = meta[:source_attestation]
      validate_provenance!(name, provenance, source_attestation)

      Entry.new(
        name: name,
        category: meta.fetch(:category),
        statement: meta.fetch(:statement),
        adapter: adapter,
        provenance: provenance,
        source_attestation: source_attestation,
        reference: Task.new(solution_path: File.join(dir, "solution.rb"), test_path: test_path, adapter: adapter),
        broken_solutions: meta.fetch(:broken).map { |b| load_broken(dir, test_path, adapter, b) }
      )
    end

    # A sourced task with no attestation fails here, loudly, for every
    # caller that loads the corpus - not just whichever test happens to
    # assert it - the same guarantee this repo already gives mechanism_free
    # broken solutions (test_every_task_carries_a_mechanism_free_broken_
    # solution_that_its_grader_rejects), just enforced one layer lower.
    def validate_provenance!(name, provenance, source_attestation)
      return unless provenance == "sourced"
      return if source_attestation.to_s.match?(/\S/)

      raise ArgumentError, "#{name}: a sourced task requires a source_attestation (training-data cutoff), got #{source_attestation.inspect}"
    end

    def load_broken(dir, test_path, adapter, b)
      id = b.fetch(:id)
      BrokenSolution.new(
        id: id,
        misconception: b.fetch(:misconception),
        task: Task.new(solution_path: File.join(dir, "broken", "#{id}.rb"), test_path: test_path, adapter: adapter)
      )
    end
  end
end

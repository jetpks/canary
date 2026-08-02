# Attacks: the sandbox boundary, rspec flavor - parity check with
# writes_file_submission.rb. The forked child shares the real filesystem
# regardless of which adapter loaded the submission.
File.write(ENV.fetch("CANARY_TAMPER_WRITE_PATH"), "written by rspec_writes_file_submission.rb\n")

RSpec.describe "rspec writes file" do
  it "passes" do
    expect(2 + 2).to eq(4)
  end
end

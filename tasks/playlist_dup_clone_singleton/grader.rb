RSpec.describe "Playlist copy protocol" do
  it "appends tracks in order" do
    playlist = Playlist.new
    playlist.add(:a)
    playlist.add(:b)
    expect(playlist.tracks).to eq([:a, :b])
  end

  it "gives dup its own tracks array, independent of the original" do
    playlist = Playlist.new([:a])
    copy = playlist.dup
    copy.add(:b)
    expect(playlist.tracks).to eq([:a])
  end

  it "gives clone its own tracks array, independent of the original" do
    playlist = Playlist.new([:a])
    copy = playlist.clone
    copy.add(:b)
    expect(playlist.tracks).to eq([:a])
  end

  it "does not carry singleton behavior over to a dup" do
    playlist = Playlist.new([:a])
    def playlist.bonus_track
      :hidden
    end
    expect(playlist.dup.respond_to?(:bonus_track)).to eq(false)
  end

  it "carries singleton behavior over to a clone" do
    playlist = Playlist.new([:a])
    def playlist.bonus_track
      :hidden
    end
    expect(playlist.clone.bonus_track).to eq(:hidden)
  end

  it "always comes back unfrozen from dup, regardless of the original" do
    playlist = Playlist.new([:a]).freeze
    expect(playlist.dup.frozen?).to eq(false)
  end

  it "matches the original's frozen state by default from clone" do
    frozen_playlist = Playlist.new([:a]).freeze
    unfrozen_playlist = Playlist.new([:b])
    expect(frozen_playlist.clone.frozen?).to eq(true)
    expect(unfrozen_playlist.clone.frozen?).to eq(false)
  end

  it "honors an explicit clone(freeze: false) override on a frozen original" do
    playlist = Playlist.new([:a]).freeze
    expect(playlist.clone(freeze: false).frozen?).to eq(false)
  end

  it "honors an explicit clone(freeze: true) override on an unfrozen original" do
    playlist = Playlist.new([:a])
    expect(playlist.clone(freeze: true).frozen?).to eq(true)
  end
end

# A gem-shaped submission: a small Queue implementation plus a realistic
# ~20-example test suite, used to measure per-rollout cost against
# something bigger than a toy.
#
# Named BenchQueue rather than Queue: this file models an untrusted
# submission, and this harness exists to detect submissions that reopen
# core classes - its own fixture shouldn't do the thing it's built to catch.
class BenchQueue
  Empty = Class.new(StandardError)

  def initialize
    @items = []
  end

  def enqueue(item)
    @items.push(item)
    self
  end

  def dequeue
    raise Empty, "queue is empty" if @items.empty?

    @items.shift
  end

  def peek
    raise Empty, "queue is empty" if @items.empty?

    @items.first
  end

  def empty?
    @items.empty?
  end

  def size
    @items.size
  end

  def to_a
    @items.dup
  end
end

RSpec.describe BenchQueue do
  subject(:queue) { described_class.new }

  it "starts empty" do
    expect(queue).to be_empty
  end

  it "starts with zero size" do
    expect(queue.size).to eq(0)
  end

  it "returns self from enqueue" do
    expect(queue.enqueue(1)).to be(queue)
  end

  it "increases size on enqueue" do
    queue.enqueue(1)
    expect(queue.size).to eq(1)
  end

  it "increases size on multiple enqueues" do
    queue.enqueue(1).enqueue(2).enqueue(3)
    expect(queue.size).to eq(3)
  end

  it "is not empty after enqueue" do
    queue.enqueue(1)
    expect(queue).not_to be_empty
  end

  it "dequeues in FIFO order" do
    queue.enqueue(1).enqueue(2).enqueue(3)
    expect([queue.dequeue, queue.dequeue, queue.dequeue]).to eq([1, 2, 3])
  end

  it "removes the item on dequeue" do
    queue.enqueue(1).enqueue(2)
    queue.dequeue
    expect(queue.size).to eq(1)
  end

  it "raises when dequeuing an empty queue" do
    expect { queue.dequeue }.to raise_error(BenchQueue::Empty, "queue is empty")
  end

  it "peeks the first item" do
    queue.enqueue(1).enqueue(2)
    expect(queue.peek).to eq(1)
  end

  it "does not remove the item on peek" do
    queue.enqueue(1).enqueue(2)
    queue.peek
    expect(queue.size).to eq(2)
  end

  it "raises when peeking an empty queue" do
    expect { queue.peek }.to raise_error(BenchQueue::Empty)
  end

  it "returns items as an array" do
    queue.enqueue(1).enqueue(2)
    expect(queue.to_a).to eq([1, 2])
  end

  it "does not let to_a mutate the queue" do
    queue.enqueue(1)
    queue.to_a << 2
    expect(queue.size).to eq(1)
  end

  it "tracks size after enqueue and dequeue" do
    queue.enqueue(1).enqueue(2)
    queue.dequeue
    expect(queue.size).to eq(1)
  end

  it "is empty again after enqueue and dequeue" do
    queue.enqueue(1)
    queue.dequeue
    expect(queue).to be_empty
  end

  it "accepts nil as an item" do
    queue.enqueue(nil)
    expect(queue.peek).to be_nil
  end

  it "accepts items of various types" do
    queue.enqueue(1).enqueue("two").enqueue(:three).enqueue([4])
    expect(queue.dequeue).to eq(1)
    expect(queue.dequeue).to eq("two")
    expect(queue.dequeue).to eq(:three)
    expect(queue.dequeue).to eq([4])
  end

  it "stays consistent across many enqueues and dequeues" do
    100.times { |i| queue.enqueue(i) }
    100.times { |i| expect(queue.dequeue).to eq(i) }
    expect(queue).to be_empty
  end

  it "raises with the expected message" do
    expect { queue.dequeue }.to raise_error("queue is empty")
  end

  it "reports a growing size as items are added" do
    sizes = (1..5).map { |i| queue.enqueue(i).size }
    expect(sizes).to eq([1, 2, 3, 4, 5])
  end
end

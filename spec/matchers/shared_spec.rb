# frozen_string_literal: true

RSpec.shared_examples 'all the sub-matchers of multi matcher has the same context' do
  let(:context) { Mongory::Utils::Context.new }
  let(:matcher) { described_class.new(condition, context: context) }

  it 'has the same context as the matcher' do
    expect(matcher.context).to be(context)
    matcher.matchers.each do |sub_matcher|
      expect(sub_matcher.context).to be(context)
    end
  end
end

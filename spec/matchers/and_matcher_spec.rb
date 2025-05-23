# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mongory::Matchers::AndMatcher do
  describe '#match?' do
    subject { described_class.new(condition) }

    context 'when all subconditions are satisfied' do
      let(:condition) do
        [
          { 'age' => { '$gte' => 18 } },
          { 'name' => { '$regex' => 'foo' } }
        ]
      end

      it_behaves_like 'all the sub-matchers of multi matcher has the same context'
      it { is_expected.to be_match('age' => 20, 'name' => 'foobar') }
      it { is_expected.not_to be_match('age' => 20, 'name' => 'bar') }
      it { is_expected.not_to be_match('age' => 20) }
      it { is_expected.not_to be_match('age') }
      it { is_expected.not_to be_match(20) }
      it { is_expected.not_to be_match(nil) }
      it { is_expected.not_to be_match(anything) }
    end

    context 'when condition is not an array' do
      let(:condition) { { 'age' => { '$gte' => 18 } } }

      it 'raises Mongory::TypeError' do
        expect { subject }.to raise_error(Mongory::TypeError)
      end
    end

    context 'when condition contains non-hash elements' do
      let(:condition) { [{ 'age' => { '$gte' => 18 } }, anything] }

      it 'raises Mongory::TypeError' do
        expect { subject }.to raise_error(Mongory::TypeError)
      end
    end
  end
end

# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mongory::Matchers::OrMatcher do
  describe '#match?' do
    subject { described_class.new(condition) }

    context 'when any subcondition is satisfied' do
      let(:condition) do
        [
          { 'age' => { '$gte' => 18 } },
          { 'name' => { '$regex' => 'foo' } }
        ]
      end

      it { is_expected.to be_match('age' => 20, 'name' => 'bar') }
      it { is_expected.to be_match('age' => 16, 'name' => 'foobar') }
      it { is_expected.to be_match('age' => 18) }
      it { is_expected.to be_match('name' => 'foo') }
      it { is_expected.not_to be_match('age' => 10, 'name' => 'bar') }
      it { is_expected.not_to be_match('age' => 10) }
      it { is_expected.not_to be_match({}) }
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

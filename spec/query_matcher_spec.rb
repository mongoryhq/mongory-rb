# frozen_string_literal: true

require 'spec_helper'

DummyModel = Struct.new(:as_json)
FakeBsonId = Struct.new(:to_s)

converter = Mongory.data_converter

converter.register(DummyModel) do
  converter.convert(as_json)
end

converter.register(FakeBsonId, :to_s)

RSpec.describe Mongory::QueryMatcher, type: :model do
  subject { described_class.new(condition) }

  context '#match?' do
    context 'basic condition' do
      context 'match all document when condition is empty' do
        let(:condition) { {} }

        it { is_expected.to be_match(name: 'Bruno Mars') }
        it { is_expected.to be_match('string') }
        it { is_expected.to be_match(2_147_483_647) }
        it { is_expected.to be_match(anything) }
      end

      context '1 layer match' do
        let(:condition) do
          {
            name: 'Bruno Mars'
          }
        end

        it { is_expected.to be_match(name: 'Bruno Mars') }
        it { is_expected.to be_match(name: 'Bruno Mars', other: anything) }
        it { is_expected.to be_match(DummyModel.new(name: 'Bruno Mars', other: anything)) }
        it { is_expected.not_to be_match(name: 'bruno mars') }
        it { is_expected.not_to be_match(name: 'Marco Polo') }
        it { is_expected.not_to be_match(DummyModel.new(name: 'Marco Polo')) }
      end

      context 'match with different type key' do
        let(:condition) do
          {
            name: 'Bruno Mars'
          }
        end

        it { is_expected.to be_match('name' => 'Bruno Mars') }
        it { is_expected.to be_match('name' => 'Bruno Mars', 'other' => anything) }
        it { is_expected.to be_match(DummyModel.new('name' => 'Bruno Mars', 'other' => anything)) }
        it { is_expected.not_to be_match('name' => 'bruno mars') }
        it { is_expected.not_to be_match('name' => 'Marco Polo') }
        it { is_expected.not_to be_match(DummyModel.new('name' => 'Marco Polo')) }
      end

      context '2 layer match' do
        let(:condition) do
          {
            profile: {
              age: 18
            }
          }
        end

        it { is_expected.to be_match(name: anything, profile: { age: 18 }) }
        it { is_expected.to be_match(name: anything, profile: { age: 18, other: anything }) }
        it { is_expected.not_to be_match(name: anything, profile: { age: anything }) }
        it { is_expected.not_to be_match(name: anything, profile: { age: anything, other: anything }) }
      end

      context 'more layer match' do
        context 'with string' do
          let(:condition) do
            {
              do: { you: { want: { to: { build: { a: { snow: { man: 'No!' } } } } } } }
            }
          end

          it {
            is_expected.to be_match(name: anything,
                                    do: { you: { want: { to: { build: { a: { snow: { man: 'No!' } } } } } } })
          }
          it {
            is_expected.not_to be_match(name: anything,
                                        do: { you: { want: { to: { build: { a: { snow: { man: 'Yes!' } } } } } } })
          }
          it { is_expected.not_to be_match(anything) }
        end

        context 'with dot key' do
          let(:condition) do
            {
              'do.you.want.to.build.a.snow.man': 'No!'
            }
          end

          it {
            is_expected.to be_match(name: anything,
                                    do: { you: { want: { to: { build: { a: { snow: { man: 'No!' } } } } } } })
          }
          it {
            is_expected.not_to be_match(name: anything,
                                        do: { you: { want: { to: { build: { a: { snow: { man: 'Yes!' } } } } } } })
          }
          it { is_expected.not_to be_match(anything) }
        end

        context 'with nil' do
          let(:condition) do
            {
              do: { you: { want: { to: { build: { a: { snow: { man: nil } } } } } } }
            }
          end

          it do
            is_expected.to be_match(name: anything,
                                    do: { you: { want: { to: { build: { a: { snow: { man: nil } } } } } } })
          end

          it do
            is_expected.to be_match(name: anything,
                                    do: { you: { want: { to: { build: { a: { snow: {} } } } } } })
          end

          it do
            is_expected.not_to be_match(name: anything,
                                        do: { you: { want: { to: { build: { a: { snow: { man: anything } } } } } } })
          end

          it { is_expected.not_to be_match(anything) }
          it { is_expected.not_to be_match(nil) }
        end
      end

      context 'match array' do
        let(:condition) do
          {
            '2': 'target'
          }
        end

        it { is_expected.to be_match([anything, anything, 'target']) }
        it { is_expected.not_to be_match([anything, 'target', anything]) }
        it { is_expected.not_to be_match([anything, 'target']) }
        it { is_expected.not_to be_match([]) }
      end

      context 'match array with nil' do
        let(:condition) do
          {
            '2': nil
          }
        end

        it { is_expected.to be_match([anything, anything, nil]) }
        it { is_expected.to be_match([anything, nil]) }
        it { is_expected.to be_match([]) }
        it { is_expected.not_to be_match([anything, nil, anything]) }
      end

      context 'match array with non-array' do
        let(:condition) do
          {
            tags: tags
          }
        end

        context 'when compare with array' do
          let(:tags) { %w(tag1 tag2) }

          it { is_expected.to be_match(tags: %w(tag1 tag2)) }
          it { is_expected.not_to be_match(tags: ['tag1']) }
          it { is_expected.not_to be_match(tags: %w(tag2 tag1)) }
          it { is_expected.not_to be_match(tags: 'tag1') }
        end

        context 'when compare with string' do
          let(:tags) { 'tag1' }

          it { is_expected.to be_match(tags: ['tag1']) }
          it { is_expected.to be_match(tags: %w(tag1 tag2)) }
          it { is_expected.to be_match(tags: %w(tag2 tag1)) }
          it { is_expected.not_to be_match(tags: ['tag2']) }
        end

        context 'when compare with condition' do
          let(:tags) do
            {
              tag1: 13
            }
          end

          it { is_expected.to be_match(tags: [{ tag1: 13, tag2: anything }]) }
          it { is_expected.to be_match(tags: [{ tag1: 13 }, { tag2: anything }]) }
          it { is_expected.not_to be_match(tags: [{ tag1: 14 }]) }
        end
      end

      context 'match array with condition' do
        let(:condition) do
          {
            name: 'Billy',
            age: 18
          }
        end

        let(:data1) do
          {
            name: 'Billy',
            age: 20
          }
        end
        let(:data2) do
          {
            name: 'Mary',
            age: 18
          }
        end
        let(:data3) do
          {
            name: 'Frank',
            age: 20
          }
        end
        let(:matched_data) do
          {
            name: 'Billy',
            age: 18
          }
        end

        it { is_expected.to be_match([data1, data2, matched_data]) }
        it { is_expected.not_to be_match([data1, data2, data3]) }
        it { is_expected.not_to be_match([data2, data3]) }
      end

      context 'fake model behavior' do
        let(:id) { FakeBsonId.new('67d3def21177ff005e59e0a4') }
        let(:model) { DummyModel.new(id: id, name: 'Frank') }

        context 'will be match eq' do
          let(:condition) { { id: '67d3def21177ff005e59e0a4' } }

          it { is_expected.to be_match(model) }
        end

        context 'will be match eq with id object' do
          let(:condition) { { id: FakeBsonId.new('67d3def21177ff005e59e0a4') } }

          it { is_expected.to be_match(model) }
        end

        context 'will be match gt' do
          let(:condition) { { :id.gt => '6760ff3335bacb003bfb43ef' } }

          it { is_expected.to be_match(model) }
        end

        context 'will be match gt with id object' do
          let(:condition) { { :id.gt => FakeBsonId.new('6760ff3335bacb003bfb43ef') } }

          it { is_expected.to be_match(model) }
        end

        context 'will not be match' do
          let(:condition) { { id: '6760ff3335bacb003bfb43ef' } }

          it { is_expected.not_to be_match(model) }
        end

        context 'will not be match with id object' do
          let(:condition) { { id: FakeBsonId.new('6760ff3335bacb003bfb43ef') } }

          it { is_expected.not_to be_match(model) }
        end
      end

      context 'should match string by regexp' do
        let(:condition) do
          {
            email: /^[^@]+@mongory(app)?\.com$/
          }
        end

        it { is_expected.to be_match(email: 'bruno_mars@mongory.com') }
        it { is_expected.to be_match(email: 'bruno.mars@mongoryapp.com') }
        it { is_expected.to be_match(email: 'vocano@mongory.com') }
        it { is_expected.not_to be_match(email: 'vocano@@mongory.com') }
        it { is_expected.not_to be_match(email: 'anyone@mongoryppap.com') }
        it { is_expected.not_to be_match(email: 'anyone@mongory.com.tw') }
        it { is_expected.not_to be_match(email: 'anyone#mongory.com') }
        it { is_expected.not_to be_match(email: nil) }
        it { is_expected.not_to be_match(nil) }
        it { is_expected.not_to be_match(anything) }
      end
    end

    context 'use operator $present' do
      let(:condition) do
        {
          profile: {
            address: {
              '$present': presence
            }
          }
        }
      end

      context 'will raise error when condition value is not boolean' do
        let(:presence) { anything }

        it { expect { subject }.to raise_error(Mongory::TypeError) }
      end

      context 'with true' do
        let(:presence) { true }

        it { is_expected.to be_match(profile: { address: { key: anything } }) }
        it { is_expected.to be_match(DummyModel.new(profile: { address: { key: anything } })) }
        it { is_expected.not_to be_match(profile: { address: {} }) }
        it { is_expected.not_to be_match(profile: {}) }
        it { is_expected.not_to be_match(DummyModel.new(profile: {})) }
        it { is_expected.not_to be_match({}) }
        it { is_expected.not_to be_match(nil) }
      end

      context 'with false' do
        let(:presence) { false }

        it { is_expected.to be_match(profile: { address: {} }) }
        it { is_expected.to be_match(profile: {}) }
        it { is_expected.to be_match(DummyModel.new(profile: {})) }
        it { is_expected.not_to be_match(profile: { address: { key: anything } }) }
        it { is_expected.not_to be_match(DummyModel.new(profile: { address: { key: anything } })) }
        it { is_expected.not_to be_match({}) }
        it { is_expected.not_to be_match(nil) }
      end
    end

    context 'use operator $exists' do
      let(:condition) do
        { a: 123, b: nil, :c.exists => exists }
      end

      context 'when exists' do
        let(:exists) { true }

        it { is_expected.to be_match(a: 123, b: nil, c: anything) }
        it { is_expected.to be_match(a: 123, c: anything) }
        it { is_expected.to be_match(DummyModel.new(a: 123, b: nil, c: anything)) }
        it { is_expected.not_to be_match(a: 123, b: nil) }
        it { is_expected.not_to be_match(DummyModel.new(a: 123, b: nil)) }
      end

      context 'when not exists' do
        let(:exists) { false }

        it { is_expected.to be_match(a: 123, b: nil) }
        it { is_expected.to be_match(DummyModel.new(a: 123, b: nil)) }
        it { is_expected.not_to be_match(a: 123, b: nil, c: anything) }
        it { is_expected.not_to be_match(DummyModel.new(a: 123, b: nil, c: anything)) }
      end
    end

    context 'use operator $or' do
      let(:condition) do
        {
          profile: {
            '$or': conditions
          }
        }
      end

      context 'will raise error when condition value not an array' do
        let(:conditions) { anything }

        it { expect { subject }.to raise_error(Mongory::TypeError) }
      end

      context 'will matched if any of conditions is match document' do
        let(:conditions) do
          [
            { name: 'Joy' },
            { age: 18 }
          ]
        end

        it { is_expected.to be_match(profile: { name: 'Joy', age: 18 }) }
        it { is_expected.to be_match(profile: { name: 'Joy', age: 20 }) }
        it { is_expected.to be_match(profile: { name: 'Frank', age: 18 }) }
        it { is_expected.not_to be_match(profile: { name: 'Frank', age: 20 }) }
        it { is_expected.not_to be_match(profile: {}) }
        it { is_expected.not_to be_match(profile: nil) }
        it { is_expected.not_to be_match(name: 'Joy', age: 18) }
        it { is_expected.not_to be_match({}) }
        it { is_expected.not_to be_match(anything) }
        it { is_expected.not_to be_match(nil) }
      end
    end

    context 'use operator $and' do
      let(:condition) do
        {
          profile: {
            '$and': conditions
          }
        }
      end

      context 'will raise error when condition value not an array' do
        let(:conditions) { anything }

        it { expect { subject }.to raise_error(Mongory::TypeError) }
      end

      context 'will matched if all of conditions is match document' do
        let(:conditions) do
          [
            { name: 'Joy' },
            { age: 18 }
          ]
        end

        it { is_expected.to be_match(profile: { name: 'Joy', age: 18 }) }
        it { is_expected.not_to be_match(profile: { name: 'Joy', age: 20 }) }
        it { is_expected.not_to be_match(profile: { name: 'Frank', age: 18 }) }
        it { is_expected.not_to be_match(profile: { name: 'Frank', age: 20 }) }
        it { is_expected.not_to be_match(profile: {}) }
        it { is_expected.not_to be_match(profile: nil) }
        it { is_expected.not_to be_match(name: 'Joy', age: 18) }
        it { is_expected.not_to be_match({}) }
        it { is_expected.not_to be_match(anything) }
        it { is_expected.not_to be_match(nil) }
      end
    end

    context 'use operator $regex' do
      let(:condition) do
        {
          email: {
            '$regex': regex
          }
        }
      end

      shared_examples_for 'regex behaviors' do
        it { is_expected.to be_match(email: 'bruno_mars@mongory.com') }
        it { is_expected.to be_match(email: 'bruno.mars@mongoryapp.com') }
        it { is_expected.to be_match(email: 'vocano@mongory.com') }
        it { is_expected.not_to be_match(email: 'vocano@@mongory.com') }
        it { is_expected.not_to be_match(email: 'anyone@mongoryppap.com') }
        it { is_expected.not_to be_match(email: 'anyone@mongory.com.tw') }
        it { is_expected.not_to be_match(email: 'anyone#mongory.com') }
        it { is_expected.not_to be_match(anything) }
      end

      context 'will raise error when condition value is not a string' do
        let(:regex) { anything }

        it { expect { subject }.to raise_error(Mongory::TypeError) }
      end

      context 'should match string by regexp as string' do
        let(:regex) { '^[^@]+@mongory(app)?\.com$' }

        it_behaves_like 'regex behaviors'
      end

      context 'should match string by regexp' do
        let(:regex) { /^[^@]+@mongory(app)?\.com$/ }

        it_behaves_like 'regex behaviors'
      end
    end

    context 'use operator $eq' do
      let(:name) { 'Frank' }

      shared_examples_for 'eq behaviors' do
        it { is_expected.to be_match(name: 'Frank') }
        it { is_expected.not_to be_match(name: 'frank') }
        it { is_expected.not_to be_match(name: anything) }
        it { is_expected.not_to be_match(anything) }
        it { is_expected.not_to be_match(nil) }
      end

      context 'will matched' do
        let(:condition) do
          {
            name: { '$eq': name }
          }
        end

        it_behaves_like 'eq behaviors'
      end

      context 'by built-in symbol mongoid methods will matched' do
        let(:condition) do
          {
            :name.eq => name
          }
        end

        it_behaves_like 'eq behaviors'
      end
    end

    context 'use operator $ne' do
      let(:not_name) { nil }

      shared_examples_for 'ne behaviors' do
        it { is_expected.to be_match(name: 'Oreo') }
        it { is_expected.to be_match(name: anything) }
        it { is_expected.not_to be_match(anything) }
        it { is_expected.not_to be_match(nil) }
      end

      context 'will matched' do
        let(:condition) do
          {
            name: { '$ne': not_name }
          }
        end

        it_behaves_like 'ne behaviors'
      end

      context 'by built-in symbol mongoid methods will matched' do
        let(:condition) do
          {
            :name.ne => not_name
          }
        end

        it_behaves_like 'ne behaviors'
      end
    end

    context 'use operator $not' do
      let(:reverse_condition) { { name: { '$regex': 'an' } } }

      shared_examples_for 'not behaviors' do
        it { is_expected.to be_match(profile: { name: 'Oreo' }) }
        it { is_expected.to be_match(profile: { name: nil }) }
        it { is_expected.to be_match({}) }
        it { is_expected.not_to be_match(anything) }
        it { is_expected.not_to be_match(profile: { name: 'Frank' }) }
        it { is_expected.not_to be_match(profile: { name: 'angular' }) }
      end

      context 'will matched' do
        let(:condition) do
          {
            profile: { '$not': reverse_condition }
          }
        end

        it_behaves_like 'not behaviors'
      end

      context 'by built-in symbol mongoid methods will matched' do
        let(:condition) do
          {
            :profile.not => reverse_condition
          }
        end

        it_behaves_like 'not behaviors'
      end
    end

    context 'use operator $gt' do
      let(:age) { 18 }

      shared_examples_for 'gt behaviors' do
        it { is_expected.to be_match(profile: { age: 20 }) }
        it { is_expected.not_to be_match(profile: { age: 18 }) }
        it { is_expected.not_to be_match(profile: { age: 17 }) }
        it { is_expected.not_to be_match(profile: { age: nil }) }
        it { is_expected.not_to be_match(profile: {}) }
        it { is_expected.not_to be_match(profile: nil) }
        it { is_expected.not_to be_match({}) }
        it { is_expected.not_to be_match(anything) }
      end

      context 'will matched' do
        let(:condition) do
          {
            profile: { age: { '$gt': age } }
          }
        end

        it_behaves_like 'gt behaviors'
      end

      context 'by built-in symbol mongoid methods will matched' do
        let(:condition) do
          {
            profile: { :age.gt => age }
          }
        end

        it_behaves_like 'gt behaviors'
      end
    end

    context 'use operator $gte' do
      let(:age) { 18 }

      shared_examples_for 'gte behaviors' do
        it { is_expected.to be_match(profile: { age: 20 }) }
        it { is_expected.to be_match(profile: { age: 18 }) }
        it { is_expected.not_to be_match(profile: { age: 17 }) }
        it { is_expected.not_to be_match(profile: { age: nil }) }
        it { is_expected.not_to be_match(profile: {}) }
        it { is_expected.not_to be_match(profile: nil) }
        it { is_expected.not_to be_match({}) }
        it { is_expected.not_to be_match(anything) }
      end

      context 'will matched' do
        let(:condition) do
          {
            profile: { age: { '$gte': age } }
          }
        end

        it_behaves_like 'gte behaviors'
      end

      context 'by built-in symbol mongoid methods will matched' do
        let(:condition) do
          {
            profile: { :age.gte => age }
          }
        end

        it_behaves_like 'gte behaviors'
      end
    end

    context 'use operator $lt' do
      let(:age) { 18 }

      shared_examples_for 'lt behaviors' do
        it { is_expected.to be_match(profile: { age: 17 }) }
        it { is_expected.not_to be_match(profile: { age: 18 }) }
        it { is_expected.not_to be_match(profile: { age: 20 }) }
        it { is_expected.not_to be_match(profile: { age: nil }) }
        it { is_expected.not_to be_match(profile: {}) }
        it { is_expected.not_to be_match(profile: nil) }
        it { is_expected.not_to be_match({}) }
        it { is_expected.not_to be_match(anything) }
      end

      context 'will matched' do
        let(:condition) do
          {
            profile: { age: { '$lt': age } }
          }
        end

        it_behaves_like 'lt behaviors'
      end

      context 'by built-in symbol mongoid methods will matched' do
        let(:condition) do
          {
            profile: { :age.lt => age }
          }
        end

        it_behaves_like 'lt behaviors'
      end
    end

    context 'use operator $lte' do
      let(:age) { 18 }

      shared_examples_for 'lte behaviors' do
        it { is_expected.to be_match(profile: { age: 17 }) }
        it { is_expected.to be_match(profile: { age: 18 }) }
        it { is_expected.not_to be_match(profile: { age: 20 }) }
        it { is_expected.not_to be_match(profile: { age: nil }) }
        it { is_expected.not_to be_match(profile: {}) }
        it { is_expected.not_to be_match(profile: nil) }
        it { is_expected.not_to be_match({}) }
        it { is_expected.not_to be_match(anything) }
      end

      context 'will matched' do
        let(:condition) do
          {
            profile: { age: { '$lte': age } }
          }
        end

        it_behaves_like 'lte behaviors'
      end

      context 'by built-in symbol mongoid methods will matched' do
        let(:condition) do
          {
            profile: { :age.lte => age }
          }
        end

        it_behaves_like 'lte behaviors'
      end
    end

    context 'use operator $in' do
      let(:collection) { %w(foo bar) }

      shared_examples_for 'in behaviors' do
        it { is_expected.to be_match(name: 'foo') }
        it { is_expected.to be_match(name: 'bar') }
        it { is_expected.to be_match(name: ['foo']) }
        it { is_expected.to be_match(name: ['bar']) }
        it { is_expected.to be_match(name: %w(foo bar)) }
        it { is_expected.not_to be_match(name: 'lala') }
        it { is_expected.not_to be_match(name: nil) }
        it { is_expected.not_to be_match(anything) }
      end

      context 'will raise error when use `$in` operator with non-array' do
        let(:condition) do
          {
            name: { '$in': anything }
          }
        end

        it { expect { subject }.to raise_error(Mongory::TypeError) }
      end

      context 'will matched' do
        let(:condition) do
          {
            name: { '$in': collection }
          }
        end

        it_behaves_like 'in behaviors'
      end

      context 'by built-in symbol mongoid methods will matched' do
        let(:condition) do
          {
            :name.in => collection
          }
        end

        it_behaves_like 'in behaviors'
      end
    end

    context 'use operator $nin' do
      let(:collection) { %w(foo bar) }

      shared_examples_for 'nin behaviors' do
        it { is_expected.to be_match(name: 'ann') }
        it { is_expected.to be_match(name: nil) }
        it { is_expected.not_to be_match(anything) }
        it { is_expected.not_to be_match(name: 'foo') }
        it { is_expected.not_to be_match(name: 'bar') }
      end

      context 'will raise error when use `$nin` operator with non-array' do
        let(:condition) do
          {
            name: { '$nin': anything }
          }
        end

        it { expect { subject }.to raise_error(Mongory::TypeError) }
      end

      context 'will matched' do
        let(:condition) do
          {
            name: { '$nin': collection }
          }
        end

        it_behaves_like 'nin behaviors'
      end

      context 'by built-in symbol mongoid methods will matched' do
        let(:condition) do
          {
            :name.nin => collection
          }
        end

        it_behaves_like 'nin behaviors'
      end
    end

    context 'use operator $elemMatch' do
      shared_examples_for 'elem match behavior' do
        it { is_expected.to be_match(abilities: [{ name: 'attack', power: 10 }, { name: 'eat', power: 59 }]) }
        it { is_expected.to be_match(abilities: [{ name: 'healing', power: 30 }, { name: 'run', power: 40 }]) }
        it { is_expected.to be_match(abilities: [{ name: 'cooking', power: 70 }, { name: 'drink', power: 10 }]) }
        it { is_expected.not_to be_match(abilities: [{ name: 'eat', power: 59 }]) }
        it { is_expected.not_to be_match(abilities: [{ name: 'run', power: 40 }]) }
        it { is_expected.not_to be_match(abilities: []) }
        it { is_expected.not_to be_match(abilities: nil) }
        it { is_expected.not_to be_match({}) }
        it { is_expected.not_to be_match([]) }
        it { is_expected.not_to be_match(nil) }
      end

      context 'will match' do
        let(:condition) do
          {
            abilities: {
              '$elemMatch': {
                '$or': [
                  { name: 'attack' },
                  { name: 'healing' },
                  { power: { '$gt': 60 } }
                ]
              }
            }
          }
        end

        it_behaves_like 'elem match behavior'
      end

      context 'by built-in symbol mongoid methods will matched' do
        let(:condition) do
          {
            :abilities.elem_match => {
              '$or': [
                { name: 'attack' },
                { name: 'healing' },
                { :power.gt => 60 }
              ]
            }
          }
        end

        it_behaves_like 'elem match behavior'
      end

      context 'symbol key match' do
        let(:condition) do
          {
            :abilities.elem_match => { name: 'attack' }
          }
        end

        it { is_expected.to be_match(abilities: [{ name: 'attack', power: 10 }, { name: 'eat', power: 59 }]) }
        it { is_expected.not_to be_match(abilities: [{ name: 'healing', power: 30 }, { name: 'run', power: 40 }]) }
        it { is_expected.not_to be_match(abilities: [{ name: 'cooking', power: 70 }, { name: 'drink', power: 10 }]) }
        it { is_expected.not_to be_match(abilities: [{ name: 'eat', power: 59 }]) }
        it { is_expected.not_to be_match(abilities: [{ name: 'run', power: 40 }]) }
        it { is_expected.not_to be_match(abilities: []) }
        it { is_expected.not_to be_match(abilities: nil) }
        it { is_expected.not_to be_match({}) }
        it { is_expected.not_to be_match([]) }
        it { is_expected.not_to be_match(nil) }
      end
    end

    context 'use operator $every' do
      shared_examples_for 'every behavior' do
        it { is_expected.to be_match(abilities: [{ name: 'attack', power: 10 }, { name: 'attack', power: 59 }]) }
        it { is_expected.not_to be_match(abilities: []) }
        it { is_expected.not_to be_match(abilities: [{ name: 'attack', power: 10 }, { name: 'eat', power: 59 }]) }
        it { is_expected.not_to be_match(abilities: [{ name: 'eat', power: 59 }]) }
        it { is_expected.not_to be_match(abilities: [{ name: 'run', power: 40 }]) }
        it { is_expected.not_to be_match(abilities: nil) }
        it { is_expected.not_to be_match({}) }
        it { is_expected.not_to be_match([]) }
        it { is_expected.not_to be_match(nil) }
      end

      context 'will match' do
        let(:condition) do
          {
            abilities: {
              '$every': { name: 'attack' }
            }
          }
        end

        it_behaves_like 'every behavior'
      end

      context 'by built-in symbol mongoid methods will matched' do
        let(:condition) do
          {
            :abilities.every => { name: 'attack' }
          }
        end

        it_behaves_like 'every behavior'
      end

      context 'not match empty array via conbinding present operator' do
        let(:condition) do
          {
            :abilities.every => { name: 'attack' },
            :abilities.present => true
          }
        end

        it { is_expected.to be_match(abilities: [{ name: 'attack', power: 10 }, { name: 'attack', power: 59 }]) }
        it { is_expected.not_to be_match(abilities: []) }
      end
    end
  end
end

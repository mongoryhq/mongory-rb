# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mongory::QueryMatcher, type: :model do
  context '#to_proc' do
    subject { described_class.new(condition).tap(&:prepare_query).to_proc }

    context 'basic condition' do
      context 'match all document when condition is empty' do
        let(:condition) { {} }

        it { expect(subject.call(name: 'Bruno Mars')).to be_truthy }
        it { expect(subject.call('string')).to be_truthy }
        it { expect(subject.call(2_147_483_647)).to be_truthy }
        it { expect(subject.call(anything)).to be_truthy }
      end

      context '1 layer match' do
        let(:condition) do
          {
            name: 'Bruno Mars'
          }
        end

        it { expect(subject.call(name: 'Bruno Mars')).to be_truthy }
        it { expect(subject.call(name: 'Bruno Mars', other: anything)).to be_truthy }
        it { expect(subject.call(name: 'bruno mars')).to be_falsy }
        it { expect(subject.call(name: 'Marco Polo')).to be_falsy }
      end

      context 'match with different type key' do
        let(:condition) do
          {
            name: 'Bruno Mars'
          }
        end

        it { expect(subject.call('name' => 'Bruno Mars')).to be_truthy }
        it { expect(subject.call('name' => 'Bruno Mars', 'other' => anything)).to be_truthy }
        it { expect(subject.call('name' => 'bruno mars')).to be_falsy }
        it { expect(subject.call('name' => 'Marco Polo')).to be_falsy }
      end

      context '2 layer match' do
        let(:condition) do
          {
            profile: {
              age: 18
            }
          }
        end

        it { expect(subject.call(name: anything, profile: { age: 18 })).to be_truthy }
        it { expect(subject.call(name: anything, profile: { age: 18, other: anything })).to be_truthy }
        it { expect(subject.call(name: anything, profile: { age: anything })).to be_falsy }
        it { expect(subject.call(name: anything, profile: { age: anything, other: anything })).to be_falsy }
      end

      context 'more layer match' do
        context 'with string' do
          let(:condition) do
            {
              do: { you: { want: { to: { build: { a: { snow: { man: 'No!' } } } } } } }
            }
          end

          it {
            expect(subject.call(name: anything,
                                do: { you: { want: { to: { build: { a: { snow: { man: 'No!' } } } } } } })).to be_truthy
          }
          it {
            expect(subject.call(name: anything,
                                do: { you: { want: { to: { build: { a: { snow: { man: 'Yes!' } } } } } } })).to be_falsy
          }
          it { expect(subject.call(anything)).to be_falsy }
        end

        context 'with dot key' do
          let(:condition) do
            {
              'do.you.want.to.build.a.snow.man': 'No!'
            }
          end

          it {
            expect(subject.call(name: anything,
                                do: { you: { want: { to: { build: { a: { snow: { man: 'No!' } } } } } } })).to be_truthy
          }
          it {
            expect(subject.call(name: anything,
                                do: { you: { want: { to: { build: { a: { snow: { man: 'Yes!' } } } } } } })).to be_falsy
          }
          it { expect(subject.call(anything)).to be_falsy }
        end

        context 'with nil' do
          let(:condition) do
            {
              do: { you: { want: { to: { build: { a: { snow: { man: nil } } } } } } }
            }
          end

          it {
            expect(subject.call(name: anything,
                                do: { you: { want: { to: { build: { a: { snow: { man: nil } } } } } } })).to be_truthy
          }

          it {
            expect(subject.call(name: anything,
                                do: { you: { want: { to: { build: { a: { snow: {} } } } } } })).to be_truthy
          }

          it {
            expect(
              subject.call(
                name: anything, do: { you: { want: { to: { build: { a: { snow: { man: anything } } } } } } }
              )
            ).to be_falsy
          }

          it { expect(subject.call(anything)).to be_falsy }
          it { expect(subject.call(nil)).to be_falsy }
        end
      end

      context 'match array' do
        let(:condition) do
          {
            '2': 'target'
          }
        end

        it { expect(subject.call([anything, anything, 'target'])).to be_truthy }
        it { expect(subject.call([anything, 'target', anything])).to be_falsy }
        it { expect(subject.call([anything, 'target'])).to be_falsy }
        it { expect(subject.call([])).to be_falsy }
      end

      context 'match array with nil' do
        let(:condition) do
          {
            '2': nil
          }
        end

        it { expect(subject.call([anything, anything, nil])).to be_truthy }
        it { expect(subject.call([anything, nil])).to be_truthy }
        it { expect(subject.call([])).to be_truthy }
        it { expect(subject.call([anything, nil, anything])).to be_falsy }
      end

      context 'match array with non-array' do
        let(:condition) do
          {
            tags: tags
          }
        end

        context 'when compare with array' do
          let(:tags) { %w(tag1 tag2) }

          it { expect(subject.call(tags: %w(tag1 tag2))).to be_truthy }
          it { expect(subject.call(tags: ['tag1'])).to be_falsy }
          it { expect(subject.call(tags: %w(tag2 tag1))).to be_falsy }
          it { expect(subject.call(tags: 'tag1')).to be_falsy }
        end

        context 'when compare with string' do
          let(:tags) { 'tag1' }

          it { expect(subject.call(tags: ['tag1'])).to be_truthy }
          it { expect(subject.call(tags: %w(tag1 tag2))).to be_truthy }
          it { expect(subject.call(tags: %w(tag2 tag1))).to be_truthy }
          it { expect(subject.call(tags: ['tag2'])).to be_falsy }
        end

        context 'when compare with condition' do
          let(:tags) do
            {
              tag1: 13
            }
          end

          it { expect(subject.call(tags: [{ tag1: 13, tag2: anything }])).to be_truthy }
          it { expect(subject.call(tags: [{ tag1: 13 }, { tag2: anything }])).to be_truthy }
          it { expect(subject.call(tags: [{ tag1: 14 }])).to be_falsy }
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

        it { expect(subject.call([data1, data2, matched_data])).to be_truthy }
        it { expect(subject.call([data1, data2, data3])).to be_falsy }
        it { expect(subject.call([data2, data3])).to be_falsy }
      end

      context 'should match string by regexp' do
        let(:condition) do
          {
            email: /^[^@]+@mongory(app)?\.com$/
          }
        end

        it { expect(subject.call(email: 'bruno_mars@mongory.com')).to be_truthy }
        it { expect(subject.call(email: 'bruno.mars@mongoryapp.com')).to be_truthy }
        it { expect(subject.call(email: 'vocano@mongory.com')).to be_truthy }
        it { expect(subject.call(email: 'vocano@@mongory.com')).to be_falsy }
        it { expect(subject.call(email: 'anyone@mongoryppap.com')).to be_falsy }
        it { expect(subject.call(email: 'anyone@mongory.com.tw')).to be_falsy }
        it { expect(subject.call(email: 'anyone#mongory.com')).to be_falsy }
        it { expect(subject.call(email: nil)).to be_falsy }
        it { expect(subject.call(nil)).to be_falsy }
        it { expect(subject.call(anything)).to be_falsy }
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

        it { expect(subject.call(profile: { address: { key: anything } })).to be_truthy }
        it { expect(subject.call(profile: { address: {} })).to be_falsy }
        it { expect(subject.call(profile: {})).to be_falsy }
        it { expect(subject.call({})).to be_falsy }
        it { expect(subject.call(nil)).to be_falsy }
      end

      context 'with false' do
        let(:presence) { false }

        it { expect(subject.call(profile: { address: {} })).to be_truthy }
        it { expect(subject.call(profile: {})).to be_truthy }
        it { expect(subject.call(profile: { address: { key: anything } })).to be_falsy }
        it { expect(subject.call({})).to be_falsy }
        it { expect(subject.call(nil)).to be_falsy }
      end
    end

    context 'use operator $exists' do
      let(:condition) do
        { a: 123, b: nil, :c.exists => exists }
      end

      context 'when exists' do
        let(:exists) { true }

        it { expect(subject.call(a: 123, b: nil, c: anything)).to be_truthy }
        it { expect(subject.call(a: 123, c: anything)).to be_truthy }
        it { expect(subject.call(a: 123, b: nil)).to be_falsy }
      end

      context 'when not exists' do
        let(:exists) { false }

        it { expect(subject.call(a: 123, b: nil)).to be_truthy }
        it { expect(subject.call(a: 123, b: nil, c: anything)).to be_falsy }
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

        it { expect(subject.call(profile: { name: 'Joy', age: 18 })).to be_truthy }
        it { expect(subject.call(profile: { name: 'Joy', age: 20 })).to be_truthy }
        it { expect(subject.call(profile: { name: 'Frank', age: 18 })).to be_truthy }
        it { expect(subject.call(profile: { name: 'Frank', age: 20 })).to be_falsy }
        it { expect(subject.call(profile: {})).to be_falsy }
        it { expect(subject.call(profile: nil)).to be_falsy }
        it { expect(subject.call(name: 'Joy', age: 18)).to be_falsy }
        it { expect(subject.call({})).to be_falsy }
        it { expect(subject.call(anything)).to be_falsy }
        it { expect(subject.call(nil)).to be_falsy }
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

        it { expect(subject.call(profile: { name: 'Joy', age: 18 })).to be_truthy }
        it { expect(subject.call(profile: { name: 'Joy', age: 20 })).to be_falsy }
        it { expect(subject.call(profile: { name: 'Frank', age: 18 })).to be_falsy }
        it { expect(subject.call(profile: { name: 'Frank', age: 20 })).to be_falsy }
        it { expect(subject.call(profile: {})).to be_falsy }
        it { expect(subject.call(profile: nil)).to be_falsy }
        it { expect(subject.call(name: 'Joy', age: 18)).to be_falsy }
        it { expect(subject.call({})).to be_falsy }
        it { expect(subject.call(anything)).to be_falsy }
        it { expect(subject.call(nil)).to be_falsy }
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
        it { expect(subject.call(email: 'bruno_mars@mongory.com')).to be_truthy }
        it { expect(subject.call(email: 'bruno.mars@mongoryapp.com')).to be_truthy }
        it { expect(subject.call(email: 'vocano@mongory.com')).to be_truthy }
        it { expect(subject.call(email: 'vocano@@mongory.com')).to be_falsy }
        it { expect(subject.call(email: 'anyone@mongoryppap.com')).to be_falsy }
        it { expect(subject.call(email: 'anyone@mongory.com.tw')).to be_falsy }
        it { expect(subject.call(email: 'anyone#mongory.com')).to be_falsy }
        it { expect(subject.call(anything)).to be_falsy }
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
        it { expect(subject.call(name: 'Frank')).to be_truthy }
        it { expect(subject.call(name: 'frank')).to be_falsy }
        it { expect(subject.call(name: anything)).to be_falsy }
        it { expect(subject.call(anything)).to be_falsy }
        it { expect(subject.call(nil)).to be_falsy }
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
        it { expect(subject.call(name: 'Oreo')).to be_truthy }
        it { expect(subject.call(name: anything)).to be_truthy }
        it { expect(subject.call(anything)).to be_falsy }
        it { expect(subject.call(nil)).to be_falsy }
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
        it { expect(subject.call(profile: { name: 'Oreo' })).to be_truthy }
        it { expect(subject.call(profile: { name: nil })).to be_truthy }
        it { expect(subject.call({})).to be_truthy }
        it { expect(subject.call(anything)).to be_falsy }
        it { expect(subject.call(profile: { name: 'Frank' })).to be_falsy }
        it { expect(subject.call(profile: { name: 'angular' })).to be_falsy }
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
        it { expect(subject.call(profile: { age: 20 })).to be_truthy }
        it { expect(subject.call(profile: { age: 18 })).to be_falsy }
        it { expect(subject.call(profile: { age: 17 })).to be_falsy }
        it { expect(subject.call(profile: { age: nil })).to be_falsy }
        it { expect(subject.call(profile: {})).to be_falsy }
        it { expect(subject.call(profile: nil)).to be_falsy }
        it { expect(subject.call({})).to be_falsy }
        it { expect(subject.call(anything)).to be_falsy }
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
        it { expect(subject.call(profile: { age: 20 })).to be_truthy }
        it { expect(subject.call(profile: { age: 18 })).to be_truthy }
        it { expect(subject.call(profile: { age: 17 })).to be_falsy }
        it { expect(subject.call(profile: { age: nil })).to be_falsy }
        it { expect(subject.call(profile: {})).to be_falsy }
        it { expect(subject.call(profile: nil)).to be_falsy }
        it { expect(subject.call({})).to be_falsy }
        it { expect(subject.call(anything)).to be_falsy }
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
        it { expect(subject.call(profile: { age: 17 })).to be_truthy }
        it { expect(subject.call(profile: { age: 18 })).to be_falsy }
        it { expect(subject.call(profile: { age: 20 })).to be_falsy }
        it { expect(subject.call(profile: { age: nil })).to be_falsy }
        it { expect(subject.call(profile: {})).to be_falsy }
        it { expect(subject.call(profile: nil)).to be_falsy }
        it { expect(subject.call({})).to be_falsy }
        it { expect(subject.call(anything)).to be_falsy }
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
        it { expect(subject.call(profile: { age: 17 })).to be_truthy }
        it { expect(subject.call(profile: { age: 18 })).to be_truthy }
        it { expect(subject.call(profile: { age: 20 })).to be_falsy }
        it { expect(subject.call(profile: { age: nil })).to be_falsy }
        it { expect(subject.call(profile: {})).to be_falsy }
        it { expect(subject.call(profile: nil)).to be_falsy }
        it { expect(subject.call({})).to be_falsy }
        it { expect(subject.call(anything)).to be_falsy }
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
        it { expect(subject.call(name: 'foo')).to be_truthy }
        it { expect(subject.call(name: 'bar')).to be_truthy }
        it { expect(subject.call(name: ['foo'])).to be_truthy }
        it { expect(subject.call(name: ['bar'])).to be_truthy }
        it { expect(subject.call(name: %w(foo bar))).to be_truthy }
        it { expect(subject.call(name: 'lala')).to be_falsy }
        it { expect(subject.call(name: nil)).to be_falsy }
        it { expect(subject.call(anything)).to be_falsy }
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
        it { expect(subject.call(name: 'ann')).to be_truthy }
        it { expect(subject.call(name: nil)).to be_truthy }
        it { expect(subject.call(anything)).to be_falsy }
        it { expect(subject.call(name: 'foo')).to be_falsy }
        it { expect(subject.call(name: 'bar')).to be_falsy }
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
        it {
          expect(subject.call(abilities: [{ name: 'attack', power: 10 }, { name: 'eat', power: 59 }])).to be_truthy
        }
        it {
          expect(subject.call(abilities: [{ name: 'healing', power: 30 }, { name: 'run', power: 40 }])).to be_truthy
        }
        it {
          expect(subject.call(abilities: [{ name: 'cooking', power: 70 }, { name: 'drink', power: 10 }])).to be_truthy
        }
        it { expect(subject.call(abilities: [{ name: 'eat', power: 59 }])).to be_falsy }
        it { expect(subject.call(abilities: [{ name: 'run', power: 40 }])).to be_falsy }
        it { expect(subject.call(abilities: [])).to be_falsy }
        it { expect(subject.call(abilities: nil)).to be_falsy }
        it { expect(subject.call({})).to be_falsy }
        it { expect(subject.call([])).to be_falsy }
        it { expect(subject.call(nil)).to be_falsy }
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

        it { expect(subject.call(abilities: [{ name: 'attack', power: 10 }, { name: 'eat', power: 59 }])).to be_truthy }
        it { expect(subject.call(abilities: [{ name: 'healing', power: 30 }, { name: 'run', power: 40 }])).to be_falsy }
        it {
          expect(subject.call(abilities: [{ name: 'cooking', power: 70 }, { name: 'drink', power: 10 }])).to be_falsy
        }
        it { expect(subject.call(abilities: [{ name: 'eat', power: 59 }])).to be_falsy }
        it { expect(subject.call(abilities: [{ name: 'run', power: 40 }])).to be_falsy }
        it { expect(subject.call(abilities: [])).to be_falsy }
        it { expect(subject.call(abilities: nil)).to be_falsy }
        it { expect(subject.call({})).to be_falsy }
        it { expect(subject.call([])).to be_falsy }
        it { expect(subject.call(nil)).to be_falsy }
      end
    end

    context 'use operator $every' do
      shared_examples_for 'every behavior' do
        it {
          expect(subject.call(abilities: [{ name: 'attack', power: 10 }, { name: 'attack', power: 59 }])).to be_truthy
        }
        it { expect(subject.call(abilities: [])).to be_falsy }
        it { expect(subject.call(abilities: [{ name: 'attack', power: 10 }, { name: 'eat', power: 59 }])).to be_falsy }
        it { expect(subject.call(abilities: [{ name: 'eat', power: 59 }])).to be_falsy }
        it { expect(subject.call(abilities: [{ name: 'run', power: 40 }])).to be_falsy }
        it { expect(subject.call(abilities: nil)).to be_falsy }
        it { expect(subject.call({})).to be_falsy }
        it { expect(subject.call([])).to be_falsy }
        it { expect(subject.call(nil)).to be_falsy }
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

        it {
          expect(subject.call(abilities: [{ name: 'attack', power: 10 }, { name: 'attack', power: 59 }])).to be_truthy
        }
        it { expect(subject.call(abilities: [])).to be_falsy }
      end
    end
  end
end

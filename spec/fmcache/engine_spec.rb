require "spec_helper"
require "mock_redis"
require "active_record"
require "field_mask_parser"

describe FMCache::Engine do
  let(:redis) { MockRedis.new }
  let(:fm_parser) {
    -> (fields) {
      FieldMaskParser.parse(paths: fields, root: User)
    }
  }
  let(:engine) { FMCache::Engine.new(client: redis, fm_parser: fm_parser) }

  after do
    keys = redis.keys("*")
    redis.del(*keys) if keys.size > 0
  end

  describe "#write" do
    # TODO(south37) Add test case in which value and field_mask is incosistent

    context "when value has only id" do
      let(:value) { { id: 1 } }
      let(:fields) { ["id"] }
      let(:field_mask) { fm_parser.call(fields) }

      it "save data" do
        engine.write(values: [value], field_mask: field_mask)
        r = engine.read(ids: [1], field_mask: field_mask)
        expect(r).to eq [
          [value],
          [],
          FMCache::IncompleteInfo.new(ids: [], field_mask: fm_parser.call(["id"])),
        ]
      end
    end

    context "when value has only id but field_mask has more fields" do
      let(:value) { { id: 1 } }
      let(:fields) { ["id", "profile.introduction"] }
      let(:field_mask) { fm_parser.call(fields) }

      it "save data" do
        engine.write(values: [value], field_mask: field_mask)
        r = engine.read(ids: [1], field_mask: field_mask)
        expect(r).to eq [
          [{ id: 1, profile: { id: nil, introduction: nil } }],
          [],
          FMCache::IncompleteInfo.new(ids: [], field_mask: fm_parser.call(["id"])),
        ]
      end
    end

    context "when value has nested structure" do
      let(:value) {
        {
           id:      1,
           profile: {
             id:           3,
             introduction: "Hello",
             schools:      [
               {
                 id:    20,
                 name:  "University of Tokyo",
                 parks: []
               },
               {
                 id:    21,
                 name:  "University of Osaka",
                 parks: [
                   { id: 30, location: "Tokyo" },
                   { id: 31, location: "Osaka" },
                 ]
               },
             ]
           }
        }
      }
      let(:fields) {
        [
          "id",
          "profile.introduction",
          "profile.schools.name",
          "profile.schools.parks.location",
        ]
      }
      let(:field_mask) { fm_parser.call(fields) }

      it "save data" do
        engine.write(values: [value], field_mask: field_mask)
        r = engine.read(ids: [1], field_mask: field_mask)
        expect(r).to eq [
          [value],
          [],
          FMCache::IncompleteInfo.new(ids: [], field_mask: fm_parser.call(["id"])),
        ]
      end
    end
  end

  describe "#read" do
    context "when no data is cached" do
      let(:fields) {
        [
          "id",
          "profile.introduction",
        ]
      }
      let(:field_mask) { fm_parser.call(fields) }

      it "returns no data" do
        r = engine.read(ids: [1], field_mask: field_mask)
        expect(r).to eq [
          [],
          [],
          FMCache::IncompleteInfo.new(ids: [1], field_mask: fm_parser.call([
            "id",
            "profile.introduction",
            "profile.id",
          ])),
        ]
      end
    end

    context "when data is cached partialy" do
      let(:value) {
        {
          id: 1,
          profile: {
            id:           3,
            introduction: "Hello",
          }
        }
      }
      let(:fields) {
        [
          "id",
          "profile.introduction",
        ]
      }
      it "returns no data" do
        field_mask = fm_parser.call(fields)
        engine.write(values: [value], field_mask: field_mask)
        field_mask_read = fm_parser.call(fields + ["profile.hobby"])
        r = engine.read(ids: [1], field_mask: field_mask_read)
        expect(r).to eq [
          [],
          [value],
          FMCache::IncompleteInfo.new(ids: [1], field_mask: fm_parser.call([
            "id",
            "profile.hobby",
            "profile.id",
          ])),
        ]
      end
    end

    context "when id is deleted" do
      let(:value) {
        {
          id: 1,
          profile: {
            id:           3,
            introduction: "Hello",
            schools:      [
              {
                id:   20,
                name: "University of Tokyo",
              },
            ]
          }
        }
      }
      let(:fields) {
        [
          "id",
          "profile.introduction",
          "profile.schools.name",
        ]
      }
      let(:field_mask) { fm_parser.call(fields) }

      it "returns a part of data" do
        engine.write(values: [value], field_mask: field_mask)
        redis.hdel("fmcache:1", "profile.schools.id")
        r = engine.read(ids: [1], field_mask: field_mask)
        expect(r).to eq [
          [],
          [
            {
              id: 1,
              profile: {
                id:           3,
                introduction: "Hello",
              }
            }
          ],
          FMCache::IncompleteInfo.new(ids: [1], field_mask: fm_parser.call([
            "id",
            "profile.id",
            "profile.schools.id",
            "profile.schools.name",
          ])),
        ]
      end
    end

    context "when data is inconsistent" do
      let(:value) {
        {
          id:      1,
          name:    "Taro",
          profile: {
            id:           3,
            introduction: "Hello",
            schools:      [
              {
                id:   20,
                name: "University of Tokyo",
              },
            ]
          }
        }
      }
      let(:fields) {
        [
          "id",
          "name",
          "profile.introduction",
          "profile.schools.name",
        ]
      }
      let(:field_mask) { fm_parser.call(fields) }

      it "returns only a consistent part of data" do
        engine.write(values: [value], field_mask: field_mask)

        # Write inconsistent data
        redis.hmset(
          "fmcache:1",
          "profile.schools.name",
          FMCache::Jsonizer::DefaultJsonSerializer.dump([
            { id: 20, p_id: 2, value: "Wantedly" }
          ])
        )

        r = engine.read(ids: [1], field_mask: field_mask)
        expect(r).to eq [
          [],
          [
            {
              id:      1,
              name:    "Taro",
              profile: {
                id:           3,
                introduction: "Hello",
                schools: [],
              }
            }
          ],
          FMCache::IncompleteInfo.new(ids: [1], field_mask: fm_parser.call([
            "id",
            "profile.introduction",
            "profile.id",
            "profile.schools.name",
            "profile.schools.id",
          ])),
        ]
      end
    end
  end

  describe "#fetch" do
    context "when no data exists" do
      let(:fields) { ["id"] }
      let(:field_mask) { fm_parser.call(fields) }

      it "returns no data" do
        r = engine.fetch(ids: [1], field_mask: field_mask) do |_ids, _field_mask|
          expect(_ids).to eq [1]
          expect(_field_mask.to_paths).to eq field_mask.to_paths
          []
        end
        expect(r).to eq []
      end
    end

    context "when no data is cached" do
      let(:value) {
        {
           id:      1,
           profile: {
             id:           3,
             introduction: "Hello",
           }
        }
      }
      let(:fields) {
        [
          "id",
          "profile.introduction",
        ]
      }
      let(:field_mask) { fm_parser.call(fields) }

      it "returns no data" do
        r = engine.fetch(ids: [1], field_mask: field_mask) do |_ids, _field_mask|
          expect(_ids).to eq [1]
          expect(_field_mask.to_paths).to eq field_mask.to_paths
          [value]
        end
        expect(r).to eq [value]
      end
    end

    context "when a part of data is cached" do
      let(:cached_value) {
        {
           id:      1,
           profile: {
             id:           3,
             introduction: "Hello",
           }
        }
      }
      let(:no_cached_value) {
        {
           id:      2,
           profile: {
             id:           4,
             introduction: "Good morning",
           }
        }
      }
      let(:fields) {
        [
          "id",
          "profile.introduction",
        ]
      }
      let(:field_mask) { fm_parser.call(fields) }

      it "returns no data" do
        engine.write(values: [cached_value], field_mask: field_mask)
        r = engine.fetch(ids: [1, 2, 3], field_mask: field_mask) do |_ids, _field_mask|
          expect(_ids).to eq [2, 3]
          expect(_field_mask.to_paths).to eq field_mask.to_paths
          [no_cached_value]
        end
        expect(r).to eq [cached_value, no_cached_value]
      end
    end

    context "when a part of data is cached" do
      let(:cached_value) {
        {
           id:      1,
           name:    "Taro",
           profile: {
             id:           3,
             introduction: "Hello",
           }
        }
      }
      let(:partialy_cached_value) {
        {
           id:      2,
           name:    "Kento",
           profile: {
             id:           4,
             introduction: "Good morning",
           }
        }
      }
      let(:fields) {
        [
          "name",
          "id",
          "profile.introduction",
        ]
      }
      let(:field_mask) { fm_parser.call(fields) }

      it "returns full data" do
        engine.write(values: [cached_value], field_mask: field_mask)
        engine.write(values: [partialy_cached_value], field_mask: field_mask)

        redis.hdel("fmcache:2", "name")

        r = engine.fetch(ids: [1, 2], field_mask: field_mask) do |_ids, _field_mask|
          expect(_ids).to eq [2]
          expect(_field_mask.to_paths).to eq ["id", "name"]
          [{ id: 2, name: "Kento" }]
        end
        expect(r).to eq [cached_value, partialy_cached_value]
      end
    end

    context "when a part of data is cached" do
      let(:cached_value) {
        {
           id:      1,
           name:    "Taro",
           profile: {
             id:           3,
             introduction: "Hello",
           }
        }
      }
      let(:partialy_cached_value) {
        {
           id:      2,
           name:    "Kento",
           profile: {
             id:           4,
             introduction: "Good morning",
           }
        }
      }
      let(:no_cached_value) {
        {
           id:      3,
           name:    "Hanako",
           profile: {
             id:           5,
             introduction: "Good night",
           }
        }
      }
      let(:fields) {
        [
          "name",
          "id",
          "profile.introduction",
        ]
      }
      let(:field_mask) { fm_parser.call(fields) }

      it "returns data" do
        engine.write(values: [cached_value], field_mask: field_mask)
        engine.write(values: [partialy_cached_value], field_mask: field_mask)

        redis.hdel("fmcache:2", "name")

        r = engine.fetch(ids: [4, 3, 2, 1], field_mask: field_mask) do |_ids, _field_mask|
          expect(_ids).to eq [2, 4, 3]
          expect(_field_mask.to_paths).to eq field_mask.to_paths
          [partialy_cached_value, no_cached_value]
        end
        expect(r).to eq [no_cached_value, partialy_cached_value, cached_value]
      end
    end

    context "when fetched value is inconsistent" do
      let(:cached_value) {
        {
           id:      1,
           name:    "Taro",
           profile: {
             id:           3,
             introduction: "Hello",
           }
        }
      }
      let(:fetched_value) {
        {
           id:      1,
           profile: {
             id:      4,
             schools: [
               {
                 id:   20,
                 name: "University of Tokyo",
               }
             ],
           }
        }
      }
      let(:cached_field_mask) { fm_parser.call(["name", "profile.introduction"]) }
      let(:read_field_mask) { fm_parser.call(["name", "profile.introduction", "profile.schools.name"]) }

      it "returns a part of data" do
        engine.write(values: [cached_value], field_mask: cached_field_mask)

        expect(engine.client).to receive(:hdel).with(
          keys:   [
            "fmcache:1"
          ],
          fields: [
            "id",
            "profile.introduction",
            "profile.id",
            "profile.schools.name",
            "profile.schools.id",
          ],
        )

        r = engine.fetch(ids: [1], field_mask: read_field_mask) do |_ids, _field_mask|
          expect(_ids).to eq [1]
          expect(_field_mask.to_paths).to eq [
            "id",
            "profile.id",
            "profile.schools.id",
            "profile.schools.name",
          ]
          [fetched_value]
        end
        expect(r).to eq [
          {
            id:      1,
            name:    "Taro",
            profile: {
              id:      4,
              schools: [
                {
                  id:   20,
                  name: "University of Tokyo"
                }
              ]
            }
          }
        ]
      end
    end
  end

  describe "#delete" do
    let(:value) { { id: 1, name: "Taro" } }
    let(:fields) { ["id", "name"] }
    let(:field_mask) { fm_parser.call(fields) }

    it "deletes cache" do
      engine.write(values: [value], field_mask: field_mask)
      expect(engine.read(ids: [1], field_mask: field_mask)).to eq [
        [{ id: 1, name: "Taro" }],
        [],
        FMCache::IncompleteInfo.new(ids: [], field_mask: fm_parser.call(["id"])),
      ]
      expect(engine.delete(ids: [1])).to eq true
      expect(engine.read(ids: [1], field_mask: field_mask)).to eq [
        [],
        [],
        FMCache::IncompleteInfo.new(ids: [1], field_mask: fm_parser.call(["name", "id"])),
      ]
    end
  end

  class User < ActiveRecord::Base
    class << self
      def attribute_names
        ["id", "name"]
      end
    end

    has_one :profile
  end

  class Profile < ActiveRecord::Base
    class << self
      def attribute_names
        ["id", "introduction", "hobby"]
      end
    end

    has_many :schools
  end

  class School < ActiveRecord::Base
    class << self
      def attribute_names
        ["id", "name"]
      end
    end

    has_many :parks
  end

  class Park < ActiveRecord::Base
    class << self
      def attribute_names
        ["id", "location"]
      end
    end
  end
end

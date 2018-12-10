require "spec_helper"
require "mock_redis"
require "redis"

describe FMCache::Client do
  let(:redis) { MockRedis.new }
  let(:client) { FMCache::Client.new(redis) }

  after do
    client.del(keys: redis.keys('*'))
  rescue Redis::BaseConnectionError
    # Do nothing
  end

  describe "#set" do
    let(:values) { { "tmp" => { "f1" => "a", "f2" => "b" } } }

    it "sets values" do
      expect(client.set(values: values, ttl: 6000)).to eq true
      expect(redis.hget("tmp", "f1")).to eq "a"
      expect(redis.hget("tmp", "f2")).to eq "b"
    end

    context "when Redis is not available" do
      let(:redis) { BadConnectionRedis.new }

      it "returns false" do
        expect(client.set(values: values, ttl: 600)).to eq false
      end
    end
  end

  describe "#get" do
    it "gets values" do
      redis.hset("tmp", "f1", "c")
      redis.hset("tmp", "f2", "d")
      expect(client.get(keys: ["tmp"], fields: ["f1", "f2"])).to eq({ "tmp" => { "f1" => "c", "f2" => "d" } })
    end

    context "when Redis is not available" do
      let(:redis) { BadConnectionRedis.new }

      it "returns false" do
        expect(client.get(keys: ["tmp"], fields: ["f1", "f2"])).to eq({ "tmp" => { "f1" => nil, "f2" => nil } })
      end
    end
  end

  describe "#del" do
    it "deletes keys" do
      redis.hset("tmp", "f1", "e")
      expect(client.del(keys: ["tmp"])).to eq true
      expect(client.get(keys: ["tmp"], fields: ["f1"])).to eq({ "tmp" => { "f1" => nil } })
    end

    context "when Redis is not available" do
      let(:redis) { BadConnectionRedis.new }

      it "returns false" do
        expect(client.del(keys: ["tmp"])).to eq false
      end
    end
  end

  describe "#hdel" do
    it "deletes keys" do
      redis.hset("tmp", "f1", "e")
      redis.hset("tmp", "f2", "f")
      expect(client.hdel(keys: ["tmp"], fields: ["f1"])).to eq true
      expect(client.get(keys: ["tmp"], fields: ["f1", "f2"])).to eq({ "tmp" => { "f1" => nil, "f2" => "f" } })
    end

    context "when Redis is not available" do
      let(:redis) { BadConnectionRedis.new }

      it "returns false" do
        expect(client.hdel(keys: ["tmp"], fields: ["f1"])).to eq false
      end
    end
  end

  class BadConnectionRedis
    ["pipelined", "mapped_hmset", "mapped_hmget", "expire", "del", "hdel", "keys"].each do |m|
      define_method m do |*args, **opts|
        raise Redis::BaseConnectionError
      end
    end
  end
end


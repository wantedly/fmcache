module FMCache
  class Client
    # @param [Redis | MockRedis] client
    # @param [Proc] notifier
    def initialize(client, notifier = nil)
      @client   = client
      @notifier = notifier
    end

    attr_reader :client, :notifier

    # @param [{ String => { String => String } }] values
    # @return [Boolean]
    def set(values:, ttl:)
      client.pipelined do
        values.each do |h_key, h_values|
          client.mapped_hmset(h_key, h_values)
          client.expire(h_key, ttl)
        end
      end

      true
    rescue Redis::BaseConnectionError => e
      notify(e)
      false
    end

    # @param [<String>] keys
    # @param [<String>] fields
    # @return [{ String => { String => String } }]
    def get(keys:, fields:)
      return {} if keys.size == 0

      values = client.pipelined do
        keys.each do |key|
          client.mapped_hmget(key, *fields)
        end
      end
      keys.zip(values).to_h
    rescue Redis::BaseConnectionError => e
      notify(e)
      keys.map { |k| [k, fields.map { |f| [f, nil] }.to_h] }.to_h
    end

    # @param [<String>] keys
    # @return [Boolean]
    def del(keys:)
      if keys.size > 0
        client.del(*keys)
      end
      true
    rescue Redis::BaseConnectionError => e
      notify(e)
      false
    end

    # @param [<String>] keys
    # @param [<String>] fields
    # @return [Boolean]
    def hdel(keys:, fields:)
      client.pipelined do
        keys.each do |key|
          fields.each do |field|
            client.hdel(key, field)
          end
        end
      end
      true
    rescue Redis::BaseConnectionError => e
      notify(e)
      false
    end

  private

    # @param [Exception] e
    def notify(e)
      notifier.call(e) if notifier
    end
  end
end

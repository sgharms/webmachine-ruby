begin
  require 'fiber'
rescue LoadError
  require 'webmachine/fiber18'
end

module Webmachine
  # Subclasses of this class implement means for streamed/chunked
  # response bodies to be coerced to the negotiated character set and
  # encoded automatically as they are output to the client.
  # @api private
  StreamingEncoder = Struct.new(:resource, :encoder, :charsetter, :body)

  # Implements a streaming encoder for Enumerable response bodies, such as
  # Arrays.
  # @api private
  class EnumerableEncoder < StreamingEncoder
    include Enumerable

    # Iterates over the body, encoding and yielding individual chunks
    # of the response entity.
    # @yield [chunk]
    # @yieldparam [String] chunk a chunk of the response, encoded
    def each
      body.each do |block|
        yield resource.send(encoder, resource.send(charsetter, block.to_s))
      end
    end
  end

  # Implements a streaming encoder for callable bodies, such as
  # Proc. (essentially futures)
  # @api private
  class CallableEncoder < StreamingEncoder
    # Encodes the output of the body Proc.
    # @return [String]
    def call
      resource.send(encoder, resource.send(charsetter, body.call.to_s))
    end

    # Converts this encoder into a Proc.
    # @return [Proc] a closure that wraps the {#call} method
    # @see #call
    def to_proc
      method(:call).to_proc
    end
  end

  # Implements a streaming encoder for Fibers with the same API as the
  # EnumerableEncoder. This will resume the Fiber until it terminates
  # or returns a falsey value.
  # @api private
  class FiberEncoder < EnumerableEncoder

    # Iterates over the body by yielding to the fiber.
    # @api private
    def each
      while body.alive? && chunk = body.resume
        yield resource.send(encoder, resource.send(charsetter, chunk.to_s))
      end
    end
  end
end

# frozen_string_literal: true

module Anycable
  class CompatibilityError < StandardError; end

  module Compatibility # :nodoc:
    ActionCable::Channel::Base.prepend(Module.new do
      def stream_from(broadcasting, callback = nil, coder: nil)
        if coder.present? && coder != ActiveSupport::JSON
          raise Anycable::CompatibilityError, "Custom coders are not supported by AnyCable"
        end

        if callback.present? || block_given?
          raise Anycable::CompatibilityError,
                "Custom stream callbacks are not supported by AnyCable"
        end

        super
      end

      %w[handle_subscribe perform_action].each do |mid|
        module_eval <<~CODE, __FILE__, __LINE__ + 1
          def #{mid}(*)
            __anycable_check_ivars__ { super }
          end
        CODE
      end

      def __anycable_check_ivars__
        was_ivars = instance_variables
        res = yield
        diff = instance_variables - was_ivars

        unless diff.empty?
          raise Anycable::CompatibilityError,
                "Channel instance variables are not supported by AnyCable, " \
                "but were set: #{diff.join(', ')}"
        end

        res
      end
    end)

    ActionCable::Channel::Base.singleton_class.define_method(:periodically) do |*|
      raise Anycable::CompatibilityError, "Periodical timers are not supported by AnyCable"
    end

    ActionCable::RemoteConnections::RemoteConnection.prepend(Module.new do
      def disconnect
        raise Anycable::CompatibilityError,
              "Disconnecting remote clients is not supported by AnyCable yet"
      end
    end)
  end
end

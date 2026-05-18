# frozen_string_literal: true

module Turbo
  module Streams
    # Signed stream names prevent tampering; this channel enforces account ownership.
    class AuthorizedChannel < Turbo::StreamsChannel
      def subscribed
        stream_name = verified_stream_name_from_params
        if stream_name.present? && subscription_allowed?(stream_name)
          stream_from stream_name
        else
          reject
        end
      end

      private

      def subscription_allowed?(stream_name)
        return false unless current_user

        stream_name.split(":").all? { |gid| streamable_accessible?(gid) }
      end

      def streamable_accessible?(gid_string)
        record = GlobalID::Locator.locate(gid_string)
        case record
        when BookingRequest
          record.account_id == current_user.account_id
        else
          false
        end
      rescue ActiveRecord::RecordNotFound, URI::InvalidURIError
        false
      end
    end
  end
end

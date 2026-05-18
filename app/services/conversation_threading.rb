# frozen_string_literal: true

# Canonical vs raw thread keys for ConversationThread and InboxMessage.
# ConversationThread.provider_thread_id stores canonical ids (provider:raw).
# InboxMessage.provider_thread_id stores the provider-native / RFC thread id.
module ConversationThreading
  SEPARATOR = ":"

  module_function

  def canonical_id(provider:, provider_thread_id:, provider_message_id:)
    "#{provider}#{SEPARATOR}#{inbox_thread_id(provider_thread_id: provider_thread_id, provider_message_id: provider_message_id)}"
  end

  def canonical_id_for(inbox_message)
    canonical_id(
      provider: inbox_message.provider,
      provider_thread_id: inbox_message.provider_thread_id,
      provider_message_id: inbox_message.provider_message_id
    )
  end

  def inbox_thread_id(provider_thread_id:, provider_message_id:)
    provider_thread_id.presence || provider_message_id
  end

  def inbox_thread_id_for(inbox_message)
    inbox_thread_id(
      provider_thread_id: inbox_message.provider_thread_id,
      provider_message_id: inbox_message.provider_message_id
    )
  end

  def inbox_thread_id_from_canonical(canonical_id)
    return canonical_id if canonical_id.blank?

    provider, separator, remainder = canonical_id.partition(SEPARATOR)
    separator.present? ? remainder : canonical_id
  end

  def canonical_id_for_inbox_thread(provider:, inbox_thread_id:)
    canonical_id(provider: provider, provider_thread_id: inbox_thread_id, provider_message_id: inbox_thread_id)
  end
end

# frozen_string_literal: true

require Rails.root.join("lib/toaster/resend_delivery_method")

ActionMailer::Base.add_delivery_method :resend_api, Toaster::ResendDeliveryMethod

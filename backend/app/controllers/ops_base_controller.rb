class OpsBaseController < ApplicationController
  http_basic_authenticate_with(
    name: ENV.fetch("OPS_USERNAME", "ops"),
    password: ENV.fetch("OPS_PASSWORD", "ops")
  )
end

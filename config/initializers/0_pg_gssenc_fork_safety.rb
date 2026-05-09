# frozen_string_literal: true

# Solid Queue forks workers from a multi-threaded Ruby process. On macOS, libpq's GSS probe
# during connect pulls in XPC/logging, which is unsafe in the fork child and can SIGSEGV
# (see crash: rb_f_fork -> PQconnectPoll -> pg_GSS_have_cred_cache -> xpc_connection_resume).
if RUBY_PLATFORM.include?("darwin") && ENV["PGGSSENCMODE"].to_s.empty?
  ENV["PGGSSENCMODE"] = "disable"
end

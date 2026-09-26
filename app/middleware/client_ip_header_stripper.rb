# Drops the `Client-Ip` request header before ActionDispatch::RemoteIp reads it.
#
# Nothing between the internet and Puma sets this header: kamal-proxy reports the
# caller in `X-Forwarded-For`, and in development there is no proxy at all. So a
# `Client-Ip` header can only have come from the client, which makes it worthless
# for identifying that client.
#
# Rails consults it anyway, with two consequences we don't want:
#
#   1. When it contradicts the forwarded chain, RemoteIp raises
#      IpSpoofAttackError and the request 500s. Scanners send
#      `Client-IP: 127.0.0.1` looking for header-based access control, so this is
#      pure noise (515 such errors in three weeks).
#   2. On its own it wins outright, letting a caller pick the IP we log and rate
#      limit against.
#
# Removing the header resolves both: `request.remote_ip` comes from the forwarded
# chain, or from REMOTE_ADDR when there isn't one.
class ClientIpHeaderStripper
  def initialize(app)
    @app = app
  end

  def call(env)
    env.delete("HTTP_CLIENT_IP")
    @app.call(env)
  end
end

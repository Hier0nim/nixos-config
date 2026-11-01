# Browser identity is trusted only after forward auth; native clients keep password auth.
{
  upstream,
  proofSnippet,
}:
let
  nativeProxy = ''
    reverse_proxy ${upstream} {
      header_up X-Real-IP {remote_host}
      header_up -Remote-*
      header_up -X-Forwarded-User
      header_up -X-Copyparty-*
    }
  '';
in
''
  route {
    request_header -Remote-*
    request_header -X-Forwarded-User
    request_header -X-Copyparty-*
    request_header -Proxy-Authorization

    @nativeBasic header_regexp Authorization "(?i)^Basic[[:space:]]+[A-Za-z0-9+/]+={0,2}$"
    handle @nativeBasic {
      ${nativeProxy}
    }
    # Unauthenticated WebDAV discovery must reach the native challenge, not an HTML redirect.
    @nativeProbe method OPTIONS PROPFIND
    handle @nativeProbe {
      ${nativeProxy}
    }
    handle {
      forward_auth 127.0.0.1:9091 {
        uri /api/authz/forward-auth
        header_up -Authorization
        header_up -Proxy-Authorization
        copy_headers Remote-User
      }
      @knownUser header_regexp Remote-User ^(hieronim|sarcia)$
      handle @knownUser {
        reverse_proxy ${upstream} {
          header_up X-Real-IP {remote_host}
          header_up -Authorization
          header_up -Remote-*
          header_up -X-Forwarded-User
          header_up X-Copyparty-User {http.request.header.Remote-User}
          import ${proofSnippet}
          # Even an expired native cookie carries a reusable password-equivalent session ID.
          header_down -Set-Cookie
        }
      }
      respond 403
    }
  }
''

{ pkgs, config }:
let
  identity = config.services.authelia.instances.homelab;
  client = builtins.head (
    builtins.filter (
      client: client.client_id == "immich"
    ) identity.settings.identity_providers.oidc.clients
  );
  photos = config.services.immich.settings.oauth;
in
assert client.authorization_policy == "immich";
assert client.require_pkce && client.pkce_challenge_method == "S256";
assert client.token_endpoint_auth_method == "client_secret_post";
assert
  identity.settings.identity_providers.oidc.authorization_policies.immich == {
    default_policy = "deny";
    rules = [
      {
        policy = "one_factor";
        subject = "group:household";
      }
    ];
  };
assert photos.clientId == client.client_id;
assert photos.tokenEndpointAuthMethod == client.token_endpoint_auth_method;
assert !photos.autoRegister && photos.roleClaim == "";
assert
  photos.clientSecret._secret
  == config.clan.core.vars.generators.immich-oidc.files.client-secret.path;
assert pkgs.lib.all (uri: builtins.elem uri client.redirect_uris) [
  "https://fotki.pieczarkowo.me/auth/login"
  "https://fotki.pieczarkowo.me/user-settings"
  "app.immich:///oauth-callback"
];
pkgs.runCommand "legion-oidc-contracts"
  {
    nativeBuildInputs = [
      pkgs.python3
      pkgs.openssl
    ];
    autheliaExec = config.systemd.services.authelia-homelab.serviceConfig.ExecStart;
  }
  ''
    python3 - <<'PY'
    from pathlib import Path
    import os
    import shlex
    import shutil
    import subprocess
    import tempfile

    args = shlex.split(os.environ['autheliaExec'])
    binary = args[0]
    configs = args[args.index('--config') + 1].split(',')
    with tempfile.TemporaryDirectory() as directory:
        work = Path(directory)
        paths = []
        for index, source in enumerate(configs):
            text = Path(source).read_text().replace(
                '/var/lib/authelia-homelab/users_database.yml', str(work / 'users.yml'))
            path = work / f'{index}.yml'
            path.write_text(text)
            paths.append(str(path))
        (work / 'users.yml').write_text('users: {}\n')
        generated = subprocess.check_output(
            [binary, 'crypto', 'hash', 'generate', 'argon2', '--random', '--no-confirm'], text=True)
        digest = next(line.split(': ', 1)[1].strip() for line in generated.splitlines()
                      if line.startswith('Digest: '))
        for name in ['immich-client-hash', 'actual-client-hash', 'forgejo-client-hash', 'beszel-client-hash']:
            (work / name).write_text(digest)
        subprocess.run([shutil.which('openssl'), 'genpkey', '-algorithm', 'RSA',
                        '-pkeyopt', 'rsa_keygen_bits:2048', '-out',
                        str(work / 'oidcIssuerPrivateKeyFile')],
                       check=True, stderr=subprocess.DEVNULL)
        env = {**os.environ, 'CREDENTIALS_DIRECTORY': directory,
               'X_AUTHELIA_CONFIG_FILTERS': 'template'}
        for name, key in [
            ('jwt', 'AUTHELIA_IDENTITY_VALIDATION_RESET_PASSWORD_JWT_SECRET_FILE'),
            ('storage', 'AUTHELIA_STORAGE_ENCRYPTION_KEY_FILE'),
            ('hmac', 'AUTHELIA_IDENTITY_PROVIDERS_OIDC_HMAC_SECRET_FILE'),
        ]:
            (work / name).write_text(os.urandom(48).hex())
            env[key] = str(work / name)
        subprocess.run([binary, '--config', ','.join(paths), 'validate-config'],
                       env=env, check=True)
    PY
    touch "$out"
  ''

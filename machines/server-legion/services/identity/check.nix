{ pkgs, config }:
pkgs.runCommand "legion-oidc-contracts"
  {
    nativeBuildInputs = [
      pkgs.python3
      pkgs.openssl
    ];
    autheliaExec = config.systemd.services.authelia-homelab.serviceConfig.ExecStart;
    clientHashes = builtins.toJSON (
      map (credential: builtins.head (pkgs.lib.splitString ":" credential)) (
        builtins.filter (
          credential: pkgs.lib.hasInfix "-client-hash:" credential
        ) config.systemd.services.authelia-homelab.serviceConfig.LoadCredential
      )
    );
  }
  ''
    python3 - <<'PY'
    from pathlib import Path
    import os
    import json
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
        for name in json.loads(os.environ['clientHashes']):
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

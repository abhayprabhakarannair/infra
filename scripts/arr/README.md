# Prowlarr reconciler

`prowlarr-reconcile.sh` reconciles only declared Prowlarr objects. It creates
or updates tags, indexers, download clients, applications, and application
profiles; it never deletes objects that are not declared.

The desired-state input is JSON. This keeps the runtime dependency set to
`bash`, `curl`, and `jq`; use SOPS to encrypt the JSON state file. Do not
commit a decrypted file containing provider credentials.

Start from [prowlarr-state.example.json](prowlarr-state.example.json). Each
indexer, download client, application, and application profile is a native
Prowlarr API resource. Provider-specific `fields`, `implementation`, and
`configContract` values are passed through unchanged. Object names are their
reconciliation identities. If an `implementation` is supplied, it is also
part of the identity, protecting a same-named object of another provider.

`tagLabels` is a reconciler-only convenience field. It becomes Prowlarr's
numeric `tags` property after declared tags have been created. Use either
`tagLabels` or native `tags`, never both.

Indexers may use `appProfileName` as a convenience reference. The reconciler
creates or updates app profiles first, resolves the name to `appProfileId`,
and sends the numeric ID to Prowlarr. App profiles themselves do not accept
`tagLabels`.

Secrets use whole-value references such as `${ENV:RADARR_API_KEY}`. The
reconciler substitutes them from its process environment. That environment can
be populated with systemd credentials or a `sops-nix` secret file; values are
not printed and request bodies are sent on standard input rather than argv.

Example:

```sh
PROWLARR_API_KEY_FILE=/run/secrets/prowlarr-api-key \
PROWLARR_URL=http://127.0.0.1:9696 \
RADARR_API_KEY="$(</run/secrets/radarr-api-key)" \
scripts/arr/prowlarr-reconcile.sh --state /run/secrets/prowlarr-state.json
```

The current NixOS module provides the optional
`arr-prowlarr-reconcile.service`. Enable it with
`my.services.arr.reconcile.enable = true` after adding these SOPS secrets to
the existing encrypted `secrets/service-secrets.yaml` file:

- `arr/prowlarr-state`: the JSON state file;
- `arr/prowlarr/env`: `KEY=VALUE` lines containing `PROWLARR_API_KEY` and any
  values referenced by `${ENV:NAME}` placeholders.

The service runs after and requires Prowlarr, uses a bounded five-minute
systemd timeout, and restarts when its state or environment secret changes.
Reconciliation remains disabled by default until those secrets exist.

Run the offline unit tests with:

```sh
scripts/arr/tests/prowlarr-reconcile-test.sh
```

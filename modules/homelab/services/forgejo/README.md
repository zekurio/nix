# Forgejo runner

The optional `small` runner runs one job at a time through Podman. The runner,
job containers, and service containers share a limit of two CPUs and 4 GiB RAM.
They cannot use swap. Image pulls and the shared Podman daemon run outside this
budget. The CPU limit allows two CPUs worth of time; it does not reserve cores.

## Registration

Create a runner in Forgejo under **User settings > Actions > Runners** to serve
all repositories owned by that user. Use repository settings instead to limit
the runner to one repository. Save the UUID.

Run `sops secrets/adam.yaml` and add `forgejo_runner_token` with the raw token.
Do not add a `TOKEN=` prefix. The token must not appear in Nix source.

Then set this under `services.homelab` in Adam's configuration:

```nix
forgejo.runner = {
  enable = true;
  uuid = "UUID-FROM-FORGEJO";
};
```

The runner stays disabled until these settings and the secret are ready.
Stage new files, run `nix fmt` and `nix flake check`, then commit and push before
rebuilding Adam as described in the repository deployment guide.

Enable Actions in the repository and use `runs-on: small` in its workflow.
The default image is Debian with Node.js 22, not a full GitHub-hosted image.
Job containers must be able to resolve and reach the private Forgejo domain.

## Verify after deployment

Check `systemctl status forgejo-runner-small.service` and its journal. Run a
workflow with the following step to inspect the job container's limits:

```yaml
- run: |
    cat /sys/fs/cgroup/cpu.max
    cat /sys/fs/cgroup/memory.max
    cat /sys/fs/cgroup/memory.swap.max
```

Expect a CPU quota-to-period ratio of 2, a memory limit of `4294967296`, and a
swap limit of `0`. On Adam, use `systemd-cgls /forgejo.slice/forgejo-runner.slice`
while the job runs. The runner and its containers must appear below this slice.
This shared slice also limits the total when a job starts service containers.

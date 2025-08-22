# quick-compose shared Docker network

This folder documents the shared Docker network used by multiple compose stacks.

Network name: `quick-compose`

Create it once before bringing up any stack:

```bash
docker network create quick-compose
```

Both `nginx/docker-compose.yaml` and `postgres/docker-compose.yaml` are configured to attach to this external network.

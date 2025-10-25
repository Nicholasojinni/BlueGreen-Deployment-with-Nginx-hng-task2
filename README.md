# Blue/Green Nginx Upstreams - Stage 2 DevOps Task

## What this repo contains
- Docker Compose environment with:
  - nginx fronting blue & green app containers
  - blue app mapped to host port 8081
  - green app mapped to host port 8082
  - nginx mapped to host port 8080

## Files
- `docker-compose.yml`
- `.env.example` (copy to `.env` and fill variables)
- `nginx/start.sh` and `nginx/nginx.tmpl`
- `.github/workflows/ci.yml` (optional CI that verifies behavior)
- `DECISION.md` (explanation of choices)

## Quick start (local)
1. Copy `.env.example` to `.env` and fill `BLUE_IMAGE`, `GREEN_IMAGE`, `RELEASE_ID_BLUE`, `RELEASE_ID_GREEN`.
   ```sh
   cp .env.example .env
   # edit .env to set BLUE_IMAGE and GREEN_IMAGE and release ids
   ```
2. Make the start script executable:
   ```sh
   chmod +x nginx/start.sh
   ```
3. Start the environment:
   ```sh
   docker compose up -d
   ```
4. Confirm containers are running:
   ```sh
   docker compose ps
   ```
5. Baseline test — expect blue responses:
   ```sh
   curl -i http://localhost:8080/version
   # Look for headers:
   # X-App-Pool: blue
   # X-Release-Id: <RELEASE_ID_BLUE>
   ```

## Simulate failure (what grader will do)
Trigger chaos on the active app (blue):
```sh
curl -X POST "http://localhost:8081/chaos/start?mode=error"
```
Immediately poll the public endpoint:
```sh
end=$((SECONDS+10))
while [ $SECONDS -lt $end ]; do
  curl -s -D - http://localhost:8080/version | sed -n '1,6p'
  sleep 0.25
done
```
Expect immediate switch to green with `X-App-Pool: green` and `X-Release-Id: <RELEASE_ID_GREEN>`.

## Manual toggle of ACTIVE_POOL
To manually toggle which pool is considered active on startup, change `ACTIVE_POOL` in `.env` and restart the nginx container:
```sh
# edit .env set ACTIVE_POOL=green or blue
docker compose restart nginx
```

## Notes
- Nginx forwards upstream response headers unchanged (so `X-App-Pool` and `X-Release-Id` are preserved).
- No building of app images is performed here.

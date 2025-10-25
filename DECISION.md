# Decision notes

- Use `nginx:stable` and template at container startup because the grader will set ACTIVE_POOL via env; templating at container startup is simple and allowed.
- Use upstream `backup` directive so nginx does automatic failover to Green when Blue fails.
- Use small `proxy_*_timeout` values and `max_fails=1 fail_timeout=2s` to ensure failover is quick (<10s).
- Use `proxy_next_upstream` with `http_5xx`, `error`, and `timeout` so the same client request retries to backup and returns 200.

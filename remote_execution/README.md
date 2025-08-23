To enable Remote Execution, add the following 4 entries to `.buckconfig.local`
in the repo root, using values given by your Remote Execution provider. For
example BuildBuddy would look like this (but with a real API key):

```ini
[buck2_re_client]
engine_address = remote.buildbuddy.io
action_cache_address = remote.buildbuddy.io
cas_address = remote.buildbuddy.io
http_headers = x-buildbuddy-api-key:zzzzzzzzzzzzzzzzzzzz
```

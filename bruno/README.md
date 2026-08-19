# Bruno API Collection

This directory contains optional requests for manually proving local maintenance
diagnostics and User Service integration. It does not contain credentials,
bearer values, or secrets.

## Run locally

1. Install [Bruno](https://www.usebruno.com/).
2. Start the maintenance service with diagnostics enabled. This enables the
   otherwise-disabled testing-support endpoints:

   ```bash
   TESTING_SUPPORT_ENDPOINTS_ENABLED=true ./gradlew bootRun
   ```

3. In another terminal, create a local Bruno environment from the template:

   ```bash
   cd bruno
   cp environments/env.bru.template environments/local.bru
   ```

4. Open the repository-relative `bruno` directory as a collection. Adjust the
   local URLs only if your services use different ports.
5. Run `health` and `Maintenance/ping`. To exercise `Maintenance/auth-check`,
   obtain a test-user access token from `User Service/Get test user token` and
   store it only in the local `BEARER_TOKEN` secret.

The User Service and AAD-backed requests are optional manual checks. Local
environment files are ignored and must never be committed.

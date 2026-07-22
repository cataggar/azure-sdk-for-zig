# azure_rest_arm_avs examples

Hand-written examples that exercise the generated `azure_rest_arm_avs` client. They
live alongside (not inside) `src/` so the generator never overwrites
them.

## list_private_clouds

Lists every Microsoft.AVS private cloud visible in a subscription,
printing one row per cloud:

```
NAME                                      LOCATION        PROVISIONING_STATE
------------------------------------------------------------------------------
my-cloud                                  eastus          Succeeded
…

3 private cloud(s).
```

Auth: [`AzureCliCredential`](../../../sdk/core/identity/azure_cli.zig) —
shells out to `az account get-access-token`, so run `az login` first.

### Running

```bash
az login

cd rest/arm_avs

# 1. Subscription via env var
AZURE_SUBSCRIPTION_ID=<sub-id> zig build list-private-clouds

# 2. Subscription via positional argument
zig build list-private-clouds -- <sub-id>

# 3. Subscription via a `.env` file in the cwd
echo 'AZURE_SUBSCRIPTION_ID=<sub-id>' > .env
zig build list-private-clouds
```

The example resolves the subscription id in that order
(`argv[1]` → `$AZURE_SUBSCRIPTION_ID` → `.env`), erroring with
`error.MissingAzureSubscriptionId` if none is set.

`.env` is ignored by this package, so it is safe to drop one in the cwd for
local iteration.

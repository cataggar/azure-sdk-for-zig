# arm-avs examples

Standalone, runnable examples that exercise the generated **`arm_avs`**
client (published on the [`rest/arm_avs`](https://github.com/cataggar/azure-sdk-for-zig/tree/rest/arm_avs)
orphan branch). This project depends on that package and on
`azure_core` / `azure_identity` from the SDK `main` branch via pinned
git URLs in `build.zig.zon` — there is no local checkout required.

```bash
git clone -b examples/arm_avs https://github.com/cataggar/azure-sdk-for-zig arm-avs-examples
cd arm-avs-examples
az login
```

Auth uses [`AzureCliCredential`](https://github.com/cataggar/azure-sdk-for-zig/blob/main/sdk/identity/azure_cli.zig),
which shells out to `az account get-access-token`, so run `az login`
first.

## list-private-clouds

Lists every Microsoft.AVS private cloud visible in a subscription.

```bash
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

## list-clusters

Lists clusters within a private cloud, reached through the `Clusters`
sub-client.

```bash
zig build list-clusters -- <sub-id> <resource-group> <private-cloud>
# or via env / .env: AZURE_SUBSCRIPTION_ID, AZURE_RESOURCE_GROUP, AZURE_PRIVATE_CLOUD
```

`.env` is gitignored, so it is safe to drop one in the cwd for local
iteration.

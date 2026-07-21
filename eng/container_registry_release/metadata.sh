# Immutable common SDK package used by both Container Registry release packages.
# Defaults are origin/main immediately after PR #100. Environment overrides are
# used only by the release workflow's isolated local-remote self-tests.
AZURE_SDK_COMMIT="${AZURE_SDK_COMMIT:-c2d7812c683ae5d2cb3d769939d2027a200d7284}"
AZURE_SDK_HASH="${AZURE_SDK_HASH:-azure_sdk-0.1.0--PMlNXKHJwC-jWWN3uEDAhxGVU0CMEXEc-ZPZ4ikXCGL}"
AZURE_SDK_URL="${AZURE_SDK_URL:-git+https://github.com/cataggar/azure-sdk-for-zig}"
AZURE_SDK_GIT_URL="${AZURE_SDK_GIT_URL:-${AZURE_SDK_URL#git+}}"

REST_BRANCH="${REST_BRANCH:-rest/container_registry}"
REST_PACKAGE="${REST_PACKAGE:-azure_rest_container_registry}"
SDK_BRANCH="${SDK_BRANCH:-sdk/container_registry}"
SDK_PACKAGE="${SDK_PACKAGE:-azure_sdk_container_registry}"

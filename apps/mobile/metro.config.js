const { getDefaultConfig } = require("expo/metro-config");

const config = getDefaultConfig(__dirname);

// packages/shared-types is ESM source that imports siblings as "./enums.js" (NodeNext style,
// needed by the backend). Metro doesn't map ".js" to the ".ts" file, so retry without the extension.
const defaultResolve = config.resolver.resolveRequest;
config.resolver.resolveRequest = (context, moduleName, platform) => {
  const resolve = defaultResolve ?? context.resolveRequest;
  try {
    return resolve(context, moduleName, platform);
  } catch (err) {
    if (moduleName.startsWith(".") && moduleName.endsWith(".js")) {
      return resolve(context, moduleName.slice(0, -3), platform);
    }
    throw err;
  }
};

module.exports = config;
